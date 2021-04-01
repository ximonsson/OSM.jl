module OSM

using LibExpat, EzXML

include("elements.jl")
include("coords.jl")

"""
	struct Index
		I::Matrix{Vector{Int64}}
		precision::Int
		O::Tuple{Int,Int}
	end

This index is basically a Matrix where each element represents a square of precision
`precision` which points to a list of nodes that are inside this square.
"""
struct Index
	I::Matrix{Array{Int64,1}}
	precision::Int
	O::Tuple{Int,Int}
end

coord2index(p::AbstractFloat, precision::Int) = trunc(Int, p * 10^precision)

coord2index(p::Tuple{AbstractFloat,AbstractFloat}, precision::Int) = coord2index.(p, precision)

"""
	Index(::Vector{Node}; precision = 3)

Create an index over the nodes for faster region extraction.
"""
function Index(ns::Vector{Node}; precision::Int = 2)
	# round all node coordinates down to precision
	f(x) = coord2index(x, precision)
	Λ = map(n -> n.λ |> f, ns)
	Φ = map(n -> n.ϕ |> f, ns)

	# create vector space
	O = (minimum(Λ), minimum(Φ))  # origin
	Σ = (abs(maximum(Λ) - minimum(Λ)) + 1, abs(maximum(Φ) - minimum(Φ)) + 1)

	# fill the index matrix
	#I = reshape([Vector{Int64}() for _ in 1:*(Σ...)], Σ)
	I = Matrix{Vector{Int64}}(undef, Σ)
	for (i, c) in enumerate(zip(Λ, Φ))
		j = CartesianIndex(c .- O .+ 1)

		if !isdefined(I, LinearIndices(I)[j])
			I[j] = Vector{Int64}()
		end

		push!(I[j], ns[i].ID)
	end

	Index(I, precision, O)
end

"""
Overload indexing.
"""
function Base.getindex(I::Index, λ::AbstractFloat, ϕ::AbstractFloat)
	i = (coord2index(λ), coord2index(ϕ)) .- I.O
	Base.getindex(I.I, i...)
end

"""
function Base.getindex(I::Index, Λ::AbstractRange, Φ::AbstractRange)
	# fix step size
	Λ = minimum(Λ):1/10^I.precision:maximum(Λ)
	Φ = minimum(Φ):1/10^I.precision:maximum(Φ)

	# convert to index in matrix
	Λ = (Λ .|> coord2index) .- I.V[1]
	Φ = (Φ .|> coord2index) .- I.V[2]

	Base.getindex(I.I, Λ, Φ)
end
"""

function Base.getindex(I::Index, UL::GeodeticWGS48, LR::GeodeticWGS48)
	# convert to index in matrix
	Λ = coord2index.(UL[1]:1/10^I.precision:LR[1], I.precision)
	Φ = coord2index.(LR[2]:1/10^I.precision:UL[2], I.precision)

	# new origin
	O = (Λ[1], Φ[1])

	Index(
		Base.getindex(I.I, Λ .- I.O[1], Φ .- I.O[2]),
		I.precision,
		(Λ[1], Φ[1]),
	)
end

"""
Data structure containing data from an OSM XML document.
Read https://wiki.openstreetmap.org/wiki/OSM_XML for more information.
"""
struct Data
	nodes::Dict{Int64,Node}
	ways::Vector{Way}
	relations::Vector{Relation}
	I::Index
end

function Data(ns::Vector{Node}, ws::Vector{Way}, rs::Vector{Relation}, I::Index)
	nodes = Dict([n.ID => n for n in ns])
	Data(nodes, ws, rs, I)
end

function Data(ns::Vector{Node}, ws::Vector{Way}, rs::Vector{Relation})
	nodes = Dict([n.ID => n for n in ns])
	Data(nodes, ws, rs, ns |> Index)
end

"""
	Data(::EzXML.Document)
"""
Data(xdoc::EzXML.Document) = Data(xdoc |> nodes, xdoc |> ways, Vector{Relation}())

"""
	Data(::AbstractString)

Create Data from XML string.
"""
Data(doc::AbstractString) = doc |> parsexml |> Data

"""
	Data(::IOStream)

Extract OSM XML data from the bytestrem `io`. This could be a file or maybe the
body of an HTTP response.
"""
Data(io::IOStream) = io |> read |> String |> Data

function Base.show(io::IO, D::Data)
	print(
		io,
		"""OSM.Data:
			$(length(D.nodes)) nodes
			$(length(D.ways)) ways""",
	)
end

"""
	filternodes(::Function, ::Vector{Node})

Filter nodes on function `fn`.
"""
function filternodes(fn::Function, ns::Vector{Node})
	idx = Vector{Bool}(undef, length(ns))
	@Threads.threads for i in 1:length(ns)
		idx[i] = fn(ns[i])
	end
	ns[idx]
end

"""
	waynodes_(D::Data, w::Way)

Get nodes part of the Way `w`.
"""
waynodes(D::Data, w::Way)::Vector{Node} = [D.nodes[ref] for ref in w.nodes]

"""
	extract(ns::Vector{Node}, P::Polygon)
"""
function extract(ns::Vector{Node}, P::Polygon)
	idx = Vector{Bool}(undef, length(ns))

	@Threads.threads for i in 1:length(ns)
		idx[i] = ns[i] ∈ P
	end

	ns[idx]
end

"""
	extract(::Data, ::Polygon)

Extract area within polygon from `Data` object.
"""
function extract(D::Data, P::Polygon)
	# find nodes that are inside the polygon then filter our ways that have a
	# node within the remaining list
	ns = extract(values(D.nodes), P)
	nids = map(n -> n.ID, ns)

	ws = Vector{Bool}(undef, length(D.ways))
	@Threads.threads for i in 1:length(ws)
		ws[i] = any(D.ways[i].nodes .∈ (nids,))
	end

	rs = Vector{Relation}()  # TODO

	Data(ns, D.ways[ws], rs)
end

function extract(D::Data, UL::GeodeticWGS48, LR::GeodeticWGS48)
	i = D.I[UL, LR]
	nids = reduce(vcat, i.I)

	ns = [D.nodes[id] for id in nids]

	# TODO ways

	rs = Vector{Relation}()  # TODO

	Data(ns, D.ways, rs, i)
end

"""
	parsefile(fp::AbstractString)

Parse an XML file and return an OSM.Data object.
"""
function parsefile(fp::AbstractString)
	nodes = sizehint!(Vector{Node}(), 1e6 |> Int)
	ways = sizehint!(Vector{Way}(), 1e5 |> Int)
	relations = Vector{Relation}()

	el = nothing  # current element

	function create(_, name, attr)
		if name == "node"
			el = OSM.Node(attr)
			push!(nodes, el)
		elseif name == "way"
			el = OSM.Way(attr)
			push!(ways, el)
		elseif name == "relation"
			# TODO
			el = nothing
		elseif name == "nd"
			# safe to assume it is a way?
			addnode(el, parse(Int64, attr["ref"]))
		elseif name == "tag" && !isnothing(el)
			tag(el, attr["k"], attr["v"])
		end
	end

	cb = LibExpat.XPCallbacks()
	cb.start_element = create
	LibExpat.parsefile(fp, cb)

	Data(nodes, ways, relations)
end

include("Nominatim.jl")
include("Overpass.jl")

end
