function axpy!(y, a, x)
    @simd for idx in eachindex(x, y)
        @inbounds y[idx] = muladd(a, x[idx], y[idx])
    end
    return nothing
end

precompile(axpy!, (Vector{Float32}, Float32, Vector{Float32}))
precompile(axpy!, (Vector{Float64}, Float64, Vector{Float64}))
