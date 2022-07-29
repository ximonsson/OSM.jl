"""
In this file we group all utility functions/macro that makes it easier
extracting data from the elements such as their names and street name.
Most of these macros are just shortcuts for getting tag values.
"""

macro name(e)
	return :( gettag($(esc(e)), "name") )
end

"""
	@isaddress(e::Element)::Bool

Does the node `e` represent an address?
"""
macro isaddress(e)
	return :( hastag($(esc(e)), "addr:street") )
end

macro addr_street(e)
	return :( gettag($(esc(e)), "addr:street") )
end

macro addr_housenumber(e)
	return :( gettag($(esc(e)), "addr:housenumber") )
end

macro addr_postcode(e)
	return :( gettag($(esc(e)), "addr:postcode") )
end

macro addr_city(e)
	return :( gettag($(esc(e)), "addr:city") )
end

"""
	@ishighway(w::Way)

Does the Way element `w` represent a highway (street) of any kind?
"""
macro ishighway(w)
	return :( hastag($(esc(w)), "highway") )
end

"""
	@isbuilding(w::Way)

Does the Way element `w` represent a building?
"""
macro isbuilding(w)
	return :( hastag($(esc(w)), "building") )
end
