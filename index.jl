"""
	struct Index
		I::Matrix{Vector{Int64}}
		precision::Int
		O::Tuple{Int,Int}
	end

This index is basically a Matrix where each element represents a square of precision
`precision` which points to a list of nodes that are inside this square.
"""
struct Index
	I::Matrix{Array{Int64,1}}
	precision::Int
	O::Tuple{Int,Int}
end

coord2index(p::AbstractFloat, precision::Int) = trunc(Int, p * 10^precision)

coord2index(p::GeodeticWGS48, precision::Int) = coord2index.(p, precision)

"""
	Index(::Vector{Node}; precision = 3)

Create an index over the nodes for faster region extraction.
"""
function Index(ns::Vector{Node}; precision::Int = 2)
	# round all node coordinates down to precision
	f(x) = coord2index(x, precision)
	Λ = map(n -> n.λ |> f, ns)
	Φ = map(n -> n.ϕ |> f, ns)

	# create vector space
	O = (minimum(Λ), minimum(Φ))  # origin
	Σ = (abs(maximum(Λ) - minimum(Λ)) + 1, abs(maximum(Φ) - minimum(Φ)) + 1)

	# fill the index matrix
	#I = reshape([Vector{Int64}() for _ in 1:*(Σ...)], Σ)
	I = Matrix{Vector{Int64}}(undef, Σ)
	for (i, c) in enumerate(zip(Λ, Φ))
		j = CartesianIndex(c .- O .+ 1)

		if !isdefined(I, LinearIndices(I)[j])
			I[j] = Vector{Int64}()
		end

		push!(I[j], ns[i].ID)
	end

	Index(I, precision, O)
end

"""
Overload indexing.
"""
function Base.getindex(I::Index, λ::AbstractFloat, ϕ::AbstractFloat)
	i = (coord2index(λ), coord2index(ϕ)) .- I.O
	Base.getindex(I.I, i...)
end

"""
function Base.getindex(I::Index, Λ::AbstractRange, Φ::AbstractRange)
	# fix step size
	Λ = minimum(Λ):1/10^I.precision:maximum(Λ)
	Φ = minimum(Φ):1/10^I.precision:maximum(Φ)

	# convert to index in matrix
	Λ = (Λ .|> coord2index) .- I.V[1]
	Φ = (Φ .|> coord2index) .- I.V[2]

	Base.getindex(I.I, Λ, Φ)
end
"""

function Base.getindex(I::Index, UL::GeodeticWGS48, LR::GeodeticWGS48)
	# convert to index in matrix
	Λ = coord2index.(UL[1]:1/10^I.precision:LR[1], I.precision)
	Φ = coord2index.(LR[2]:1/10^I.precision:UL[2], I.precision)

	# new origin
	O = (Λ[1], Φ[1])

	Index(
		Base.getindex(I.I, Λ .- I.O[1], Φ .- I.O[2]),
		I.precision,
		(Λ[1], Φ[1]),
	)
end
