"""
	geojson(
		d::Data,
		w::Way,
		ns::AbstractVector{Node};
		props = (d::Data, w::Way) -> Dict(),
	)

Generate geojson for the subset of way elements and their node elements from `Data` `d`.
"""
function geojson(
		d::Data,
		w::Way,
		ns::AbstractVector{Node};
		props = (d::Data, w::Way) -> Dict(),
)
	Dict(
		:geometry => Dict(
			:coordinates => [[[n.λ, n.ϕ] for n in ns]],
			:type => "Polygon",
		),
		:properties => merge(
			Dict(:name => @name(w)),
			props(d, w),
		),
		:id => w.ID,
		:type => "Feature",
	)
end

"""
	geojson(d::Data, ws::Vector{Way}; props = (d::Data, w::Way) -> Dict())

Generate geojson for the subset of way elements from the data set `d`.
"""
function geojson(d::Data, ws::Vector{Way}; props = (d::Data, w::Way) -> Dict())
	feats = map(ws) do w
		geojson(d, w, waynodes(d, w); props = props)
	end
	Dict(:features => feats, :type => "FeatureCollection")
end

"""
	geojson(d::Data; props = (d::Data, w::Way) -> Dict())

Generate geojson for all way elements in `d`.

`props` is a function that generates custom geojson properties for a single way element
and its parent data. The name of the way element will always be in the properties.
"""
geojson(d::Data; props = (d::Data, w::Way) -> Dict()) = geojson(d, d.ways; props = props)
