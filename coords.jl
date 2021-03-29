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
