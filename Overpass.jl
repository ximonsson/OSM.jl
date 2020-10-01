module Overpass

using HTTP

const APIHOST = "http://overpass-api.de/api"
const END_MAP = "/map"

"""
	map(min_lon, min_lat, max_lon, max_lat)

Download OSM data for the given bounding box.
"""
function map(min_lat, max_lat, min_lon, max_lon)
	HTTP.request(
		"GET",
		APIHOST * END_MAP,
		query = Dict(
			:bbox => "$min_lon,$min_lat,$max_lon,$max_lat",
		),
	) |>
	r -> r.body |> String
end

end
