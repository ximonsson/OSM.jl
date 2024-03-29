import Base.==

"""
	Tag <: Pair{Symbol,String}

An element tag.
"""
const Tag = Pair{String,String}
const Tags = Dict{String,String}

function Base.show(io::IO, tags::Tags)
	for t in tags
		print(io, "\n - $t")
	end
end

Tag(el::EzXML.Node) = el["k"] => el["v"]

function Tags(el::EzXML.Node)
	map(Tag, filter(e -> e.name == "tag", elements(el))) |> Dict
end

"""
Basic element in OSM data. Can be either a Node, Way or Relation.
They all contain a `tag` field for checking associated tags.
"""
abstract type Element end

Base.length(e::Element) = 1
Base.iterate(e::Element) = (e, nothing)
Base.iterate(e::Element, nothing) = nothing

"""
	hastag(e::Element, t::String)

Is the element tagged with a certain tag?
"""
hastag(e::Element, t::String) = haskey(e.tags, t)

"""
	gettag(e::Element, k::String)::Union{String,Missing}

Get the tag value with key `k` of element `e`. Returns missing if the element does
not have a tag named `k`.
"""
gettag(e::Element, k::String) = get(e.tags, k, missing)

"""
	tag!(e::Element, t::Tag)

Add tag `t` to the `Element` struct.
"""
tag!(e::Element, t::Tag) = setindex!(e.tags, t.second, t.first)

"""
	tag!(e::Element, k::AbstractString, v::AbstractString)
"""
tag!(e::Element, k::AbstractString, v::AbstractString) = tag!(e, k => v)

"""
OSM Node; for more information about nodes read https://wiki.openstreetmap.org/wiki/Node.
"""
struct Node <: Element
	ID::Int64
	λ::Float64
	ϕ::Float64
	tags::Tags
end

"""
	Node(::EzXML.Node)

Create a Node object from the OSM XML Element.
"""
function Node(el::EzXML.Node)
	Node(
		parse(Int64, el["id"]),
		parse(Float64, el["lon"]),
		parse(Float64, el["lat"]),
		el |> Tags,
	)
end

"""
	Node(::Dict{AbstractString,AbstractString})

Create a Node from XML node attributes
"""
function Node(attr::Dict{AbstractString,AbstractString})
	Node(
		parse(Int64, attr["id"]),
		parse(Float64, attr["lon"]),
		parse(Float64, attr["lat"]),
		Tags(),
	)
end

function Base.show(io::IO, n::Node)
	nam = @name n
	print(
		io,
		"""$(n |> typeof): $(n.ID) $(nam |> ismissing ? "" : "\"$nam\"") [$(n.λ), $(n.ϕ)]""",
	)
	print(io, n.tags)
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
		e.name != "node" && continue
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
	struct Way <: Element

From OpenStreetMap wiki https://wiki.openstreetmap.org/wiki/Way
```
A way is an ordered list of nodes which normally also has at least one tag or is included
within a Relation. A way can have between 2 and 2,000 nodes, although it's possible that
faulty ways with zero or a single node exist. A way can be open or closed. A closed way is
one whose last node on the way is also the first on that way. A closed way may be interpreted
either as a closed polyline, or an area, or both.
```
"""
struct Way <: Element
	ID::Int64
	visible::Bool
	nodes::Vector{Int64}
	tags::Tags
end

"""
	Way(el::EzXML.Node)

"""
function Way(el::EzXML.Node)
	n = map(
		x -> parse(Int64, x["ref"]),
		filter(x -> x.name == "nd", elements(el)),
	)
	Way(
		parse(Int64, el["id"]),
		true, #get(el, "visible", false),
		n,
		el |> Tags,
	)
end

"""
	Way(attr::Dict{AbstractString,AbstractString})
"""
function Way(attr::Dict{AbstractString,AbstractString})
	Way(
		parse(Int64, attr["id"]),
		get(attr, "visible", "false") === "true",
		Vector{Int64}(),
		Tags(),
	)
end

function Base.show(io::IO, w::Way)
	n = @name w
	print(
		io,
		"""$(w |> typeof): $(w.ID) $(n |> ismissing ? "" : "\"$n\"") ($(length(w.nodes)))"""
	)
	print(io, w.tags)
end

"""
	addnode(w::Way, n::Int64)

Add node reference `n` to `w`.
"""
addnode!(w::Way, n::Int64) = push!(w.nodes, n)

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
	Member

A member of a `Relation`.
"""
struct Member
	ref::Int64
	type::String
	role::String
end

function Member(attr::Dict{<:AbstractString,<:AbstractString})
	Member(
		parse(Int64, attr["ref"]),
		attr["type"],
		attr["role"],
	)
end

"""
	Relation

From OpenstreetMap wiki https://wiki.openstreetmap.org/wiki/Relation

```
A relation is a group of elements. To be more exact it is one of the core data elements that
consists of one or more tags and also an ordered list of one or more nodes, ways and/or relations
as members which is used to define logical or geographic relationships between other elements.
A member of a relation can optionally have a role which describes the part that a particular
feature plays within a relation.
```
"""
struct Relation <: Element
	ID::Int64
	members::Vector{Member}
	tags::Tags
end

"""
	Relation(::Dict{AbstractString,AbstractString})

Create a Node from XML node attributes
"""
function Relation(attr::Dict{<:AbstractString,<:AbstractString})
	Relation(parse(Int64, attr["id"]), Member[], Tags())
end

function Base.show(io::IO, r::Relation)
	n = @name r
	print(
		io,
		"""$(r |> typeof) [$(type(r))]: $(r.ID) $(n |> ismissing ? "" : "\"$n\"") ($(length(r.members)))"""
	)
	print(io, r.tags)
end

function addmember!(r::Relation, mem::Dict{<:AbstractString,<:AbstractString})
	push!(r.members, Member(mem))
	return r
end

"""
	type(r::Relation)

Return the type of relation `r`.
"""
type(r::Relation)::Union{String,Missing} = gettag(r, "type")

"""
	ismember(e::Element, r::Relation)

Is the element `e` a member of relation `r`.
"""
ismember(e::Element, r::Relation) = e ∈ r.members

"""
	e ∈ r

Checks if `e` is a member of relation `r`.
"""
Base.in(e::Element, r::Relation) = ismember(e, r)

# equality functions for members
(==)(m::Member, w::Way) = (m.ref == w.ID) && (m.type == "way")
(==)(m::Member, n::Node) = (m.ref == n.ID) && (m.type == "node")
(==)(m::Member, r::Relation) = (m.ref == r.ID) && (m.type == "relation")
(==)(e::Element, m::Member) = m == e  # switcharoo
