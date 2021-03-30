module OSM

using LibExpat, EzXML

include("elements.jl")
include("coords.jl")

"""
	struct Index
		I::Matrix{Vector{Int64}}
		upperleft::Tuple{Float32,Float32}
		precision::Int
	end

This index is basically a Matrix where each element represents a square of precision
`precision` which points to a list of nodes that are inside this square.
"""
struct Index
	I::Matrix{Vector{Int64}}
	precision::Int
	V::Matrix{Tuple{Float32,Float32}}
end

function coord2index(p::AbstractFloat; precision = 3)
	(round(p, RoundDown, digits = precision) * 10^precision) |> Int
end

function space(ns::Vector{Node}; precision = 3)
	# round all node coordinates down to precision
	Λ = map(n -> n.λ |> coord2index, ns)
	Φ = map(n -> n.ϕ |> coord2index, ns)

	# vector space
	Λr = minimum(Λ):maximum(Λ)
	Φr = minimum(Φ):maximum(Φ)
	V = zip(
		repeat(Λr, 1, length(Φr)),
		repeat(Φr', length(Λr), 1),
	) |> collect

	V
end

"""
	Index(::Vector{Node}; precision = 3)

Create an index over the nodes for faster region extraction.
"""
function Index(ns::Vector{Node}; precision::Int = 3)
	# round all node coordinates down to precision
	Λ = map(n -> n.λ |> coord2index, ns)
	Φ = map(n -> n.ϕ |> coord2index, ns)

	# create vector space
	V = space(ns, precision = precision)

	# fill the index matrix
	I = reshape([Vector{Int64}() for _ in 1:length(V)], size(V))

	for (i, c) in enumerate(zip(Λ, Φ))
		j = CartesianIndex(c .- V[1] .+ 1)
		push!(I[j], ns[i].ID)
	end

	Index(I, precision, V)
end

"""
Overload indexing.
"""
Base.getindex(I::Index, i...) = Base.getindex(I.I, i...)

"""
Data structure containing data from an OSM XML document.
Read https://wiki.openstreetmap.org/wiki/OSM_XML for more information.
"""
struct Data
	nodes::Vector{Node}
	ways::Vector{Way}
	relations::Vector{Relation}
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
	waynodes(::Date, ::Way)

Extract all the nodes that are part of the way.
"""
function waynodes(D::Data, w::Way)::Vector{Node}
	filternodes(n -> n.ID ∈ w.nodes, D.nodes)
end

"""
	waynodes(::Date, ::Vector{Way})

Extract all the nodes that are part of the way.
"""
function waynodes(D::Data, ws::Vector{Way})::Vector{Node}
	ns = reduce(vcat, map(w -> w.nodes, ws)) |> unique
	filternodes(n -> n.ID ∈ ns, D.nodes)
end

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

	ns = extract(D.nodes, P)
	nids = map(n -> n.ID, ns)

	ws = Vector{Bool}(undef, length(D.ways))
	@Threads.threads for i in 1:length(ws)
		ws[i] = any(D.ways[i].nodes .∈ (nids,))
	end

	rs = Vector{Relation}()  # TODO

	Data(ns, D.ways[ws], rs)
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
