# OSM.jl

Julia packages to handle OpenStreetmap data. Nothing new, just wanted to test things on my own....

This package implements parsing and working with [OSM XML](https://wiki.openstreetmap.org/wiki/OSM_XML) data.

There are also two subpackages to this, `OSM.Nominatim` and `OSM.Overpass`, to interface towards the [Nominatim API](https://nominatim.org/release-docs/develop/api/Overview/) and the [Overpass API](https://wiki.openstreetmap.org/wiki/Overpass_API).

## Usage

First activate the project using:

```julia
] activate .
```

Then include the main file:

```julia
include("OSM.jl")
```

## Reading Data

Implementations towards both library `LibExpat.jl` and `EzXML.jl` are avaible.

If working with larger files the `OSM.parsefile(filepath::AbstractString)` function is recommended as it uses the streaming version.

```julia
data = OSM.parsefile("brazil.osm")
```

In case you have smaller files and already have loaded a file into an `EzXML.Document` object you can use `OSM.Data(doc::EzXML.Document)`.

```julia
doc = open("myneighborhood.osm") do io
	io |> read |> String |> EzXML.parsexml
end

data = doc |> OSM.Data
```

### Using `OSM.Overpass` To Download Data

This goes towards the default server that has a rate limit, so be careful using this too much. When working with large data sets might be better to download exports from [geofabrik.de](https://download.geofabrik.de/).

```julia
data = OSM.Overpass.map(λmin, λmax, φmin, φmax)
```

## Data Object

All data from a file is stored within a `OSM.Data` object that containes fields to the Nodes `nodes`, Ways `ways` and Relations `relations` (not implemented at the moment).

## Extract Data

**This is still work in progress**

You can extract subsets of the data to work with smaller data sets. You can extract based on e.g a polygon of coordinates or a bounding box. All coordinates are WGS48 now, but the are functions to convert between ECEF and ENU but they are not supported at the moment for extracting data.

```julia
# a OSM.Polygon is a Vector{Tuple{Real,Real}}
# it should not be closed for this function
neighborhood = OSM.extract(data, [(λ1, φ1), (λ2, φ2), (λ3, φ3), (λ4, φ4), (λ5, φ5)])
```

If the region you want to extract is a rectangle it would be much faster to use `OSM.extract(data::OSM.Data, upperleft::OSM.GeodeticWGS48, lowerright::OSM.GeodeticWGS48)` (OBS: `OSM.GeodeticWGS48` is just a `Tuple{Real,Real}`), because this will use the underlying `OSM.Index` (fieldname `I` on the `OSM.Data` object) to extract the region. (**This functions is still WIP to find a fast way of extracting Way elements**).

```julia
neighborhood = OSM.extract(data, (λ1, φ1), (λ3, φ3))
```

## Helper Functions

There are some helper functions that are there for convenience such as extracting Way elements that represents streets (*highways* in OSM language).

```julia
# get all streets
streets = OSM.highways(data)

# get the nodes associated to the first street
street1nodes = OSM.waynodes(data, streets[1])

# get all nodes connected to all streets
streetnodes = reduce(vcat, map(w -> OSM.waynodes(data, w), streets))
```

You can then extract a subset of the data that is only these streets.

```julia
streetdata = OSM.extract(data, streets)
```

*More helper functions are to come.*

## TODO

* [ ] implement Relation element.
* [ ] finish extract functions to include ways in fast way.
* [ ] more helper functions like extracting buildings.
