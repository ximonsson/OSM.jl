module OSM

include("Nominatim.jl")
include("Overpass.jl")

using LibExpat, EzXML, Printf

include("utils.jl")
include("elements.jl")
include("coords.jl")
include("index.jl")

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

"""
	parsefile(fp::AbstractString)

Parse an XML file and return an OSM.Data object.
"""
function parsefile(fp::AbstractString)
	nodes = sizehint!(Vector{Node}(), 1e6 |> Int)
	ways = sizehint!(Vector{Way}(), 1e5 |> Int)
	relations = sizehint!(Vector{Relation}(), 1e5 |> Int)

	el = nothing  # current element

	function create(_, name, attr)
		if name == "node"
			el = OSM.Node(attr)
			push!(nodes, el)
		elseif name == "way"
			el = OSM.Way(attr)
			push!(ways, el)
		elseif name == "relation"
			el = Relation(attr)
			push!(relations, el)
		elseif name == "nd"
			# safe to assume it is a way?
			addnode!(el, parse(Int64, attr["ref"]))
		elseif name == "member"
			# safe to assume it is a relation?
			addmember!(el, attr)
		elseif name == "tag" && !isnothing(el)
			tag!(el, attr["k"], attr["v"])
		end
	end

	cb = LibExpat.XPCallbacks()
	cb.start_element = create
	LibExpat.parsefile(fp, cb)

	Data(nodes, ways, relations)
end

function Base.show(io::IO, D::Data)
	nnod = length(D.nodes)
	nway = length(D.ways)
	nrel = length(D.relations)
	print(
		io,
		"""OSM.Data:
			nodes      $nnod
			ways       $nway
			relations  $nrel""",
	)
end

Base.length(d::OSM.Data) = 1
Base.iterate(d::OSM.Data) = (d, nothing)
Base.iterate(d::OSM.Data, nothing) = nothing

"""
	filternodes(::Function, ::AbstractVector{<:Element})

Filter `Element`s on function `fn`.

This is really just a threaded version of `filter`.
"""
function filternodes(fn::Function, ns::AbstractVector{<:Element})
	idx = Vector{Bool}(undef, length(ns))
	@inbounds @Threads.threads for i in 1:length(ns)
		idx[i] = fn(ns[i])
	end
	@inbounds ns[idx]
end

"""
	waynodes(D::Data, w::Way)

Get nodes part of the Way `w`.
"""
waynodes(D::Data, w::Way)::Vector{Node} = [D.nodes[ref] for ref in w.nodes]

"""
	highways(D::Data)::Vector{Way}

Extract all highways from the data.
"""
highways(D::Data)::Vector{Way} = filternodes(w -> @ishighway(w), D.ways)

"""
	buildings(D::Data)

Extract all the buildings from `D`.
"""
buildings(D::Data)::Vector{Way} = filternodes(x -> @isbuilding(x), D.ways)

"""
	search(::Data, ::AbstractString)

Search the data for Nodes and Ways that have the given name.
"""
function search(D::Data, n::AbstractString)
	ws = filternodes(D.ways) do way
		name = @name way
		coalesce(name == n, false)
	end

	ns = filternodes(D.nodes |> values |> collect) do node
		name = @name node
		coalesce(name == n, false)
	end

	return (ws, ns)
end

"""
	search_address(
		D::Data,
		street_name::AbstractString,
		housenumber::AbstractString,
		postcode::AbstractString = "",
		city::AbstractString = ""
	)

Search data `D` based on address.
"""
function search_address(
		D::Data,
		street::AbstractString,
		n::AbstractString,
		postcode::AbstractString = "",
		city::AbstractString = "",
)
	# ways
	ws = filternodes(D.ways) do w
		coalesce(
			@isaddress(w) && (@addr_street(w) == street) && (@addr_housenumber(w) == n),
			false,
		)
	end

	# nodes
	ns = filternodes(D.nodes |> values |> collect) do node
		coalesce(
			@isaddress(node) && (@addr_street(node) == street) && (@addr_housenumber(node) == n),
			false,
		)
	end

	return (ws, ns)
end

function path(D::Data, e1::Element, e2::Element)

end

"""
	extract(ns::Vector{Node}, P::Polygon)
"""
function extract(ns::Vector{Node}, P::Polygon)
	idx = Vector{Bool}(undef, length(ns))

	@inbounds @Threads.threads for i in 1:length(ns)
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
	@inbounds @Threads.threads for i in 1:length(ws)
		ws[i] = any(D.ways[i].nodes .∈ (nids,))
	end

	rs = Vector{Relation}()  # TODO

	Data(ns, D.ways[ws], rs)
end

"""
	extract(D::Data, UL::GeodeticWGS48, LR::GeodeticWGS48)

Extract data from `D` within area between upper left corner `UL` to lower right `LR`.
"""
function extract(D::Data, UL::GeodeticWGS48, LR::GeodeticWGS48)
	i = D.I[UL, LR]
	nids = reduce(vcat, i.I)

	ns = [D.nodes[id] for id in nids]

	# TODO ways

	rs = Vector{Relation}()  # TODO

	Data(ns, D.ways, rs, i)
end

"""
	extract(D::Data, ws::Vector{Way})

Extract data from `D` that is linked to the way elements in `ws`.
"""
function extract(D::Data, ws::Vector{Way})
	ns = reduce(vcat, map(w -> waynodes(D, w), ws))
	Data(ns, ws, D.relations)
end

end
