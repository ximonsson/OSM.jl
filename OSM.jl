module OSM

using LightXML

const Tag = Pair{Symbol,String}

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

struct Data
	nodes::Vector{Node}
end

function nodes(el::XMLElement)
	get_elements_by_tagname(el, "node") .|> Node
end

nodes(doc::XMLDocument) = nodes ∘ root

function extract(io::IOStream)
	xdoc = io |> read |> String |> parse_string
	try
		Data(nodes(xdoc))
	finally
		@debug "freeing XML document"
		xdoc |> free
	end
end

extract(s::AbstractString) = open(s) |> extract

include("Nominatim.jl")
include("Overpass.jl")

end
