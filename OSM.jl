module OSM

using LightXML

const Tag = Pair{Symbol,String}

function Tag(el::XMLElement)
	atr = el |> attributes_dict
	Symbol(atr["k"]) => atr["v"]
end

"""
	Node(::XMLElement)

Create a Node object from the OSM XML Element.
For more information about nodes read https://wiki.openstreetmap.org/wiki/Node.
"""
struct Node
	ID::Int64
	lat::Float64
	lon::Float64
	tags::Vector{Tag}

	function Node(el::XMLElement)
		atr = el |> attributes_dict
		tags = get_elements_by_tagname(el, "tag") .|> Tag
		new(
			parse(Int64, atr["id"]),
			parse(Float64, atr["lat"]),
			parse(Float64, atr["lon"]),
			tags,
		)
	end
end

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

	function Way(el::XMLElement)
		atr = el |> attributes_dict
		n = get_elements_by_tagname(el, "nd") .|> ((x -> x["ref"]) ∘ attributes_dict)
		tags = get_elements_by_tagname(el, "tag") .|> Tag
		new(parse(Int64, atr["id"]), get(atr, "visible", false), n, tags)
	end
end

"""
	Relation(el::XMLElement)

From OpenstreetMap wiki https://wiki.openstreetmap.org/wiki/Relation
```
A relation is a group of elements. To be more exact it is one of the core data elements that
consists of one or more tags and also an ordered list of one or more nodes, ways and/or relations
as members which is used to define logical or geographic relationships between other elements
. A member of a relation can optionally have a role which describes the part that a particular
feature plays within a relation.
```

"""
struct Relation

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
	nodes(el::XMLElement)

Extract all the Nodes from the OSM XML that are children to the given `el` element.
"""
function nodes(el::XMLElement)
	@debug "getting nodes within XML"
	get_elements_by_tagname(el, "node") .|> Node
end

"""
	nodes(doc::XMLDocument)

Extract all the Nodes from the OSM XML document.
This will start from the root of the document and return all Nodes found.
"""
nodes(doc::XMLDocument) = doc |> root |> nodes

"""
	ways(el::XMLElement)
"""
function ways(el::XMLElement)
	@debug "getting ways within XML"
	get_elements_by_tagname(el, "way") .|> Way
end

ways(doc::XMLDocument) = doc |> root |> ways

"""
	extract(io::IOStream)

Extract OSM XML data from the bytestrem `io`. This could be a file or maybe the
body of an HTTP response.
"""
function extract(io::IOStream)
	@debug "reading XML data"
	xdoc = io |> read |> String |> parse_string
	try
		Data(nodes(xdoc), ways(xdoc))
	finally
		@debug "freeing XML document"
		xdoc |> free
		nothing
	end
end

"""
	extract(fp::AbstractString)

Extract OSM XML data from file at file path `fp`.
"""
extract(fp::AbstractString) = open(fp) |> extract

include("Nominatim.jl")
include("Overpass.jl")

end
