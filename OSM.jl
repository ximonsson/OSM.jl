module OSM

using LightXML

const Tag = Pair{Symbol,String}

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
		new(
			parse(Int64, atr["id"]),
			parse(Float64, atr["lat"]),
			parse(Float64, atr["lon"]),
			[]
		)
	end
end

"""

"""
struct Way

end

"""

"""
struct Relation

end

"""
Data structure containing data from an OSM XML document.
Read https://wiki.openstreetmap.org/wiki/OSM_XML for more information.
"""
struct Data
	nodes::Vector{Node}
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
	extract(io::IOStream)

Extract OSM XML data from the bytestrem `io`. This could be a file or maybe the
body of an HTTP response.
"""
function extract(io::IOStream)
	@debug "reading XML data"
	xdoc = io |> read |> String |> parse_string
	try
		Data(nodes(xdoc))
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
