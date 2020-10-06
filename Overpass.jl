module Overpass

using HTTP

const APIHOST = "https://overpass-api.de/api"
const ENDPOINT_MAP = "/map"
const ENDPOINT_INTERPRETER = "/interpreter"

function query(fn::Function, q::AbstractString)
	@debug "querying" q
	io = Base.BufferStream()
	HTTP.request("POST", APIHOST * ENDPOINT_INTERPRETER, [], q, response_stream = io)
	try
		fn(io)
	finally
		close(io)
	end
end

function bbox(fn::Function, min_lat, max_lat, min_lon, max_lon)
	q = """
	nwr($min_lat,$min_lon,$max_lat,$max_lon);
	out;
	"""
	query(fn, q)
end

function bbox(min_lat, max_lat, min_lon, max_lon)
	bbox(min_lat, max_lat, min_lon, max_lon) do io
		read(io, String)
	end
end

"""
	map(min_lon, min_lat, max_lon, max_lat)

Download OSM data for the given bounding box.
"""
function map(min_lat, max_lat, min_lon, max_lon)
	HTTP.request(
		"GET",
		APIHOST * ENDPOINT_MAP,
		query = Dict(
			:bbox => "$min_lon,$min_lat,$max_lon,$max_lat",
		),
	) |>
	r -> r.body
end

end
