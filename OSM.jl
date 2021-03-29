module OSM

using LibExpat, EzXML

const Tag = Pair{Symbol,String}
const Tags = Dict{Symbol,String}
#const Tags = Vector{Tag}

function Tag(el::EzXML.Node)
	Symbol(replace(el["k"], ":" => "_")) => el["v"]
end

function Tags(el::EzXML.Node)
	map(Tag, filter(e -> e.name == "tag", elements(el))) |> Dict
end

"""
Basic element in OSM data. Can be either a Node, Way or Relation.
"""
abstract type Element end

"""
	tag(e::Element, t::Tag)

Add tag `t` to the `Element` struct.
"""
function tag(e::Element, t::Tag)
	e.tags[t.first] = t.second
end

"""
	tag(e::Element, k::AbstractString, v::AbstractString)
"""
function tag(e::Element, k::AbstractString, v::AbstractString)
	e.tags[Symbol(replace(k, ":" => "_"))] = v
end

"""
OSM Node; for more information about nodes read https://wiki.openstreetmap.org/wiki/Node.
"""
struct Node <: Element
	ID::Int64
	lat::Float64
	lon::Float64
	tags::Tags
end

"""
	Node(::EzXML.Node)

Create a Node object from the OSM XML Element.
"""
function Node(el::EzXML.Node)
	Node(
		parse(Int64, el["id"]),
		parse(Float64, el["lat"]),
		parse(Float64, el["lon"]),
		el |> Tags,
	)
end

"""
	Node(::Dict{AbstractString,AbstractString})

Create a Node from XML node attributes
"""
function Node(attr::Dict{AbstractString,AbstractString})
	Node(
		parse(Int64, attr["id"]),
		parse(Float64, attr["lat"]),
		parse(Float64, attr["lon"]),
		Tags(),
	)
end

"""
	nodes(el::EzXML.Node)

Extract all the Nodes from the OSM XML that are children to the given `el` element.
"""
function nodes(el::EzXML.Node)
	@debug "getting nodes within XML"

	els = elements(el)
	N = Vector{Node}(undef, length(els))
	i = Threads.Atomic{Int64}(1)

	@Threads.threads for e in els
		if e.name != "node"; continue; end
		n = Node(e)
		idx = Threads.atomic_add!(i, 1)
		N[idx] = n
	end

	N[1:i[]-1]
end

"""
	nodes(doc::EzXML.Document)

Extract all the Nodes from the OSM XML document.
This will start from the root of the document and return all Nodes found.
"""
nodes(doc::EzXML.Document) = doc |> root |> nodes

"""
	struct Way <: Element

From OpenStreetMap wiki https://wiki.openstreetmap.org/wiki/Way
```
A way is an ordered list of nodes which normally also has at least one tag or is included
within a Relation. A way can have between 2 and 2,000 nodes, although it's possible that
faulty ways with zero or a single node exist. A way can be open or closed. A closed way is
one whose last node on the way is also the first on that way. A closed way may be interpreted
either as a closed polyline, or an area, or both.
```
"""
struct Way <: Element
	ID::Int64
	visible::Bool
	nodes::Vector{Int64}
	tags::Tags
end

"""
	Way(el::EzXML.Node)

"""
function Way(el::EzXML.Node)
	n = map(
		x -> parse(Int64, x["ref"]),
		filter(x -> x.name == "nd", elements(el)),
	)
	Way(
		parse(Int64, el["id"]),
		true,#get(el, "visible", false),
		n,
		el |> Tags,
	)
end

"""
	Way(attr::Dict{AbstractString,AbstractString})
"""
function Way(attr::Dict{AbstractString,AbstractString})
	Way(
		parse(Int64, attr["id"]),
		get(attr, "visible", false),
		Vector{Int64}(),
		Tags(),
	)
end

"""
	addnode(w::Way, n::Int64)

Add node reference `n` to `w`.
"""
addnode(w::Way, n::Int64) = push!(w.nodes, n)

"""
	ways(el::EzXML.Node)

Return all Way elements under the given XML element.
"""
function ways(el::EzXML.Node)
	@debug "getting ways within XML"

	els = filter(x -> x.name == "way", elements(el))
	W = Vector{Way}(undef, length(els))
	i = Threads.Atomic{Int64}(1)

	@Threads.threads for e in els
		w = Way(e)
		idx = Threads.atomic_add!(i, 1)
		W[idx] = w
	end

	return W
end

"""
	ways(::XLMEzXML.Document)

Return all Way elements in the given XML document.
"""
ways(doc::EzXML.Document) = doc |> root |> ways

"""
	name(::Way)::Union{String,Missing}

Return the name of the Way. If there is no name for the way `missing` is returned.
"""
name(w::Way)::Union{String,Missing} = get(w.tags, :name, missing)

"""
	is_closed(::Way)::Bool

Return wether the way is closed or not.
"""
is_closed(w::Way)::Bool = w.nodes[1] == w.nodes[end]

"""
	is_area(::Way)::Bool

Return wether the way is an area. True if `is_area(w)`.
"""
function is_area(w::Way)::Bool
	is_closed(w)
end

"""
	is_road(::Way)::Bool
"""
function is_road(w::Way)::Bool
	!is_area(w)
end

"""
	Relation(el::EzXML.Node)

From OpenstreetMap wiki https://wiki.openstreetmap.org/wiki/Relation

```
A relation is a group of elements. To be more exact it is one of the core data elements that
consists of one or more tags and also an ordered list of one or more nodes, ways and/or relations
as members which is used to define logical or geographic relationships between other elements.
A member of a relation can optionally have a role which describes the part that a particular
feature plays within a relation.
```
"""
struct Relation <: Element
	# TODO
end

"""
Data structure containing data from an OSM XML document.
Read https://wiki.openstreetmap.org/wiki/OSM_XML for more information.
"""
struct Data
	nodes::Vector{Node}
	ways::Vector{Way}
end

"""
	Data(::EzXML.Document)
"""
Data(xdoc::EzXML.Document) = Data(xdoc |> nodes, xdoc |> ways)

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
	nodes = Vector{Node}()
	ways = Vector{Way}()

	el = nothing

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

	Data(nodes, ways)
end


"""
	ENU(X, Y, Z, φ, λ)

Convert between ECEF coordinate system and ENU using original geodetic coordinates as
reference.

TODO not sure what the X Y Z coordinates should be in this case.
"""
ENU(X, Y, Z, φ, λ) =
	[
		-sin(λ) cos(λ) 0;
		-sin(φ)*cos(λ) -sin(φ)*cos(λ) cos(φ);
		cos(φ)*cos(λ) cos(φ)*sin(λ) sin(φ);
	] *
	[X; Y; Z]

"""
	ENU(φ, λ, h = 0)

Convert between geodetic coordinates and ENU. This is done by first converting to ECEF and
then from ECEF to ENU, using the original geodetic as reference.
"""
ENU(φ, λ, h = 0) = ECEF(φ, λ, h) |> (x, y, z) -> ENU(x, y, z, φ, λ)

""" Equatorial radius in meters. """
const Re = 6378137.0 # equatorial radius

""" Polar radius in meters. """
const Rp = 6356752.3 # polar radius

""" Constant used for converting to ECEF. """
const e = 1 - Rp^2 / Re^2

"""
	ECEF(φ, λ, h = 0)

Convert from geodetic coordinates to ECEF.
"""
function ECEF(φ, λ, h = 0)
	N = Re / √(1 - e^2 * sin(φ)^2)

	(N + h) * cos(φ) * cos(λ),
	(N + h) * cos(φ) * sin(λ),
	((1 - e^2) * N + h) * sin(φ)
end

include("Nominatim.jl")
include("Overpass.jl")

end
