module OSM

using LibExpat, EzXML

include("elements.jl")
include("coords.jl")

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


"""
	extract(::Data, ::Vector{Tuple{AbstractFloat,AbstractFloat}})

Extract area within polygon from `Data` object.

If the first and last coordinate do not match, the first will be pushed to the polygon
to close it.

Coordinates need to be WGS48 geodetic coordinates.

TODO support other coordinate systems?
"""
function extract(D::Data, P::Polygon)
	# find nodes that are inside the polygon then filter our ways that have a
	# node within the remaining list

	ns = Vector{Node}()
	ws = Vector{Way}()
	rs = Vector{Relation}()

	nids = Vector{Int64}()

	lk = ReentrantLock()

	@Threads.threads for n in D.nodes
		if n ∈ P
			lock(() -> (push!(ns, n); push!(nids, n.ID)), lk)
		end
	end

	@Threads.threads for w in D.ways
		if any(w.nodes .∈ (nids,))
			lock(() -> push!(ws, w), lk)
		end
	end

	Data(ns, ws, rs)
end

"""
	parsefile(fp::AbstractString)

Parse an XML file and return an OSM.Data object.
"""
function parsefile(fp::AbstractString)
	nodes = Vector{Node}()
	ways = Vector{Way}()
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
