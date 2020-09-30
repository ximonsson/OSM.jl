module Nominatim

using HTTP, JSON

#const APIHOST = "http://localhost:7070"
const APIHOST = "https://nominatim.openstreetmap.org"
const END_SEARCH = "/search"

"""
	search(; kwargs...)

Search the Nominatim API with query parameters in kwargs.
"""
function search(; kwargs...)
	HTTP.request(
		"GET",
		APIHOST * END_SEARCH,
		query = merge(
			kwargs |> Dict,
			Dict(:format => "json"),
		),
	) |>
	r -> r.body |> (JSON.parse ∘ String)
end

end
