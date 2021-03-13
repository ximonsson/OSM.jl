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

struct Node
	ID::Int64
	lat::Float64
	lon::Float64
	tags::Tags
end

"""
	Node(::EzXML.Node)

Create a Node object from the OSM XML Element.
For more information about nodes read https://wiki.openstreetmap.org/wiki/Node.
"""
function Node(el::EzXML.Node)
	Node(
		parse(Int64, el["id"]),
		parse(Float64, el["lat"]),
		parse(Float64, el["lon"]),
		el |> Tags,
	)
end

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
	Way(el::EzXML.Node)

From OpenStreetMap wiki https://wiki.openstreetmap.org/wiki/Way
```
A way is an ordered list of nodes which normally also has at least one tag or is included
within a Relation. A way can have between 2 and 2,000 nodes, although it's possible that
faulty ways with zero or a single node exist. A way can be open or closed. A closed way is
one whose last node on the way is also the first on that way. A closed way may be interpreted
either as a closed polyline, or an area, or both.
```
"""
struct Way
	ID::Int64
	visible::Bool
	nodes::Vector{Int64}
	tags::Tags
end

function Way(el::EzXML.Node)
	n = map(
		x -> parse(Int64, x["ref"]),
		filter(x -> x.name == "nd", elements(el)),
	)
	Way(
		parse(Int64, el["id"]),
		#get(el, "visible", false),
		true,
		n,
		el |> Tags,
	)
end

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
struct Relation
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



function parsefile(fp::AbstractString)
	N = 0
	count(_, name, _) = if name == "node"; N += 1; end

	cb = LibExpat.XPCallbacks()
	cb.start_element = count
	LibExpat.parsefile(fp, cb)

	i = 1
	nodes = Vector{Node}(undef, N)
	function create(_, name, attr)
		if name == "node"
			nodes[i] = OSM.Node(attr)
			i += 1
		end
	end

	cb.start_element = create
	LibExpat.parsefile(fp, cb)

	nodes
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
