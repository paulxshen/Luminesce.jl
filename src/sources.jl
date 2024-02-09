# __precompile__(false)
(m::Number)(a...) = m
gaussian(x; μ=0, σ=1) = exp(-((x - μ) / σ)^2)

function place(a, b, start; lazy=false)
    a + pad(b, 0, Tuple(start) .- 1, size(a) .- size(b) .- Tuple(start) .+ 1)
    # place!(buf, b, start)
end
function place!(a::AbstractArray, b, start)
    buf = bufferfrom(a)
    place!(buf, b, start)
    copy(buf)
end
function place!(a, b, start)
    a[[i:j for (i, j) = zip(start, start .+ size(b) .- 1)]...] = b
end

function place!(a, b; center)
    # @show size(a), size(b), center
    place!(a, b, center .- floor.((size(b) .- 1) .÷ 2))
end



"""
    function PlaneWave(f, dims; fields...)

Constructs plane wave source

Args
- f: time function
- dims: eg -1 for wave coming from -x face
- fields: which fields to excite & their scaling constants (typically a current source, eg Jz=1)
"""
struct PlaneWave
    f
    fields
    dims
    label
    function PlaneWave(f, dims, label=""; fields...)
        new(f, fields, dims, label)
    end
end

"""
    function GaussianBeam(f, σ, center, dims; fields...)

Constructs gaussian beam source

Args
- f: time function
- σ: std dev length
- dims: eg 1 for x direction
- fields: which fields to excite & their scaling constants (typically a current source, eg Jz=1)
"""
struct GaussianBeam
    f
    σ
    fields
    center
    dims
    function GaussianBeam(f, σ, center, dims; fields...)
        new(f, σ, fields, center, dims)
    end
end
"""
    function Source(f, center, bounds; fields...)
    function Source(f, center, L::AbstractVector{<:Real}; fields...)

Constructs custom  source. Can be used to specify uniform or modal sources

Args
- f: time function
- L: source dimensions in [wavelengths]
- fields: which fields to excite & their scaling constants (typically a current source, eg Jz=1)
"""
struct Source
    f
    fields
    center
    bounds
    label
    function Source(f, center, bounds, label=""; fields...)
        new(f, fields, center, bounds, label)
    end
end
function Source(f, center, L::Union{AbstractVector{<:Real},Tuple{<:Real}}; fields...)
    Source(f, center, [[-a / 2, a / 2] for a = L]; fields...)
end

struct SourceEffect
    f
    g
    _g
    start
    center
    label
end

function SourceEffect(s::PlaneWave, dx, sizes, starts, sz0)
    @unpack f, fields, dims, label = s
    d = length(first(sizes))
    g = Dict([k => fields[k] * ones([i == abs(dims) ? 1 : sz0[i] for i = 1:d]...) / dx for k = keys(fields)])
    starts = NamedTuple([k =>
        starts[k] .+ (dims < 0 ? 0 : [i == abs(dims) ? sizes[k][i] - 1 : 0 for i = 1:d])
                         for k = keys(starts)])
    _g = Dict([k => place(zeros(F, sizes[k]), g[k], starts[k]) for k = keys(fields)])
    center = NamedTuple([k => round.(Int, starts[k] .+ size(first(values(g))) ./ 2) for k = keys(starts)])
    Dict([k => [SourceEffect(f, g[k], _g[k], starts[k], center[k], label)] for k = keys(fields)])
end

function SourceEffect(s::GaussianBeam, dx, sizes, starts, stop)
    @unpack f, σ, fields, center, dims = s
    n = round(Int, 2σ / dx)
    r = n * dx
    I = [i == abs(dims) ? (0:0) : range(-r, r, length=(2n + 1)) for i = 1:length(center)]
    g = [gaussian(norm(F.(collect(v)))) for v = Iterators.product(I...)] / dx
    start = start .- 1 .+ index(center, dx) .- round.(Int, (size(g) .- 1) ./ 2)
    _g = place(zeros(F, sz), g, start)
    Dict([k => [SourceEffect(f, g[k], _g[k], starts[k], center[k], label)] for k = keys(fields)])
end
function SourceEffect(s::Source, dx, sizes, starts, stop)
    @unpack f, fields, center, bounds, label = s
    # R = round.(Int, L ./ 2 / dx)
    # I = range.(-R, R)
    # I = [round(Int, a / dx):round(Int, b / dx) for (a, b) = bounds]
    bounds = [isa(b, Number) ? [b, b] : b for b = bounds]
    I = [b[1]:dx:b[2] for b = bounds]
    g = Dict([k => [fields[k](v...) for v = Iterators.product(I...)] / dx^count(getindex.(bounds, 1) .== getindex.(bounds, 2)) for k = keys(fields)])
    o = -1 .+ index(center, dx) .- round.(Int, (length.(I) .- 1) ./ 2)
    starts = NamedTuple([k => starts[k] .+ o for k = keys(starts)])
    _g = Dict([k => place(zeros(F, sizes[k]), g[k], starts[k]) for k = keys(fields)])
    center = NamedTuple([k => round.(Int, starts[k] .+ size(first(values(g))) ./ 2) for k = keys(starts)])
    Dict([k => [SourceEffect(f, g[k], _g[k], starts[k], center[k], label)] for k = keys(fields)])
    # n = max.(1, round.(Int, L ./ dx))
    # g = ones(n...) / dx^count(L .== 0)
    # start = start .+ round.(Int, center ./ dx .- (n .- 1) ./ 2)
end

function apply(s::SourceEffect, a, t::Real)
    @unpack g, _g, f, start = s
    # r = place(r, real(fields[k] * f(t) .* g), start)
    a .+ real(f(t) .* _g)
end
function apply(s, t::Real; kw...)
    [
        begin
            a = kw[k]
            for s = s[k]
                a = apply(s, a, t)
            end
            a
        end for k = keys(kw)
        # end for (k, a) = pairs(kw)
    ]
end

# function apply(d,t; kw...)
#     [apply(d[k], kw[k]) for k = keys(kw)]
# end