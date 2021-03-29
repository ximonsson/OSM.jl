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
	(
		(N + h) * cos(φ) * cos(λ),
		(N + h) * cos(φ) * sin(λ),
		((1 - e^2) * N + h) * sin(φ)
	)
end

abstract type Coordinate end

"""
Longitude and latitude.
"""
const GeodeticWGS48 = Tuple{Real,Real}

# ==(a::GeodeticWGS48, b::GeodeticWGS48) = a[1] == b[1] && a[2] == b[2]

"""
Polygon of geodetic WGS48 coordinates.
"""
const Polygon = Vector{GeodeticWGS48}

"""
	in(::GeodeticWGS48, ::Polygon)

Determine if the coordinate is within the polygon.

This is done using the [Even-odd Rule](https://en.wikipedia.org/wiki/Even%E2%80%93odd_rule).
"""
function Base.in((λ, ϕ)::GeodeticWGS48, P::Polygon)
	edges = zip([P[end]; P[1:end-1]], P)
	found = false

	for (a, b) in edges
		found ⊻= ((a[2] > ϕ) ⊻ (b[2] > ϕ)) && (a[1] + (ϕ - a[2]) / (b[2] - a[2]) * (b[1] - a[1]) < λ)
	end

	found
end

"""
	in(::Node, ::Polygon)

Determine if the `Node` is within the `Polygon`.
"""
Base.in(n::Node, P::Polygon) = (n.λ, n.ϕ) ∈ P

