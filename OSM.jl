module OSM

using LightXML

const Tag = Pair{Symbol,String}

function Tag(el::XMLElement)
	atr = el |> attributes_dict
	Symbol(replace(atr["k"], ":" => "_")) => atr["v"]
end

struct Node
	ID::Int64
	lat::Float64
	lon::Float64
	tags::Dict{Symbol,String}
end

"""
	Node(::XMLElement)

Create a Node object from the OSM XML Element.
For more information about nodes read https://wiki.openstreetmap.org/wiki/Node.
"""
function Node(el::XMLElement)
	atr = el |> attributes_dict
	tags = (get_elements_by_tagname(el, "tag") .|> Tag) |> Dict
	Node(
		parse(Int64, atr["id"]),
		parse(Float64, atr["lat"]),
		parse(Float64, atr["lon"]),
		tags,
	)
end

"""
	nodes(el::XMLElement)

Extract all the Nodes from the OSM XML that are children to the given `el` element.
"""
function nodes(el::XMLElement)::Vector{Node}
	@debug "getting nodes within XML"
	get_elements_by_tagname(el, "node") .|> Node
end

"""
	nodes(doc::XMLDocument)

Extract all the Nodes from the OSM XML document.
This will start from the root of the document and return all Nodes found.
"""
nodes(doc::XMLDocument)::Vector{Node} = doc |> root |> nodes

"""
	Way(el::XMLElement)

From OpenStreetMap wiki https://wiki.openstreetmap.org/wiki/Way
```
A way is an ordered list of nodes which normally also has at least one tag or is included within a Relation.
A way can have between 2 and 2,000 nodes, although it's possible that faulty ways with zero or a single
node exist. A way can be open or closed. A closed way is one whose last node on the way is also
the first on that way. A closed way may be interpreted either as a closed polyline, or an area, or both.
```
"""
struct Way
	ID::Int64
	visible::Bool
	nodes::Vector{Int64}
	tags::Dict{Symbol,String}
end

function Way(el::XMLElement)
	atr = el |> attributes_dict
	n = get_elements_by_tagname(el, "nd") .|> ((x -> x["ref"]) ∘ attributes_dict)
	tags = (get_elements_by_tagname(el, "tag") .|> Tag) |> Dict
	Way(parse(Int64, atr["id"]), get(atr, "visible", false), parse.(Int64, n), tags)
end

"""
	ways(el::XMLElement)

Return all Way elements under the given XML element.
"""
function ways(el::XMLElement)::Vector{Way}
	@debug "getting ways within XML"
	get_elements_by_tagname(el, "way") .|> Way
end

"""
	ways(::XLMDocument)

Return all Way elements in the given XML document.
"""
ways(doc::XMLDocument) = doc |> root |> ways

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
	Relation(el::XMLElement)

From OpenstreetMap wiki https://wiki.openstreetmap.org/wiki/Relation

```
A relation is a group of elements. To be more exact it is one of the core data elements that
consists of one or more tags and also an ordered list of one or more nodes, ways and/or relations
as members which is used to define logical or geographic relationships between other elements.
A member of a relation can optionally have a role which describes the part that a particular
feature plays within a relation.
```
"""
struct Relation
	# TODO
end

"""
Data structure containing data from an OSM XML document.
Read https://wiki.openstreetmap.org/wiki/OSM_XML for more information.
"""
struct Data
	nodes::Dict{Int64,Node}
	ways::Dict{Int64,Way}
end

"""
	Data(::XMLDocument)
"""
function Data(xdoc::XMLDocument)
	fn(x) = x.ID => x
	Data(
		nodes(xdoc) .|> fn |> Dict,
		ways(xdoc) .|> fn |> Dict,
	)
end

"""
	Data(::IOStream)

Extract OSM XML data from the bytestrem `io`. This could be a file or maybe the
body of an HTTP response.
"""
function Data(io::IOStream)
	xdoc = io |> read |> String |> parse_string
	try
		Data(xdoc)
	finally
		xdoc |> free
	end
end

"""
	Data(::AbstractString)

Extract OSM XML data from file at file path `fp`.
"""
Data(fp::AbstractString) = fp |> open |> Data

"""
	ENU(X, Y, Z, φ, λ)

Convert between ECEF coordinate system and ENU using original geodetic coordinates as reference.

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

Convert between geodetic coordinates and ENU. This is done by first converting to ECEF and then from ECEF
to ENU, using the original geodetic as reference.
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
