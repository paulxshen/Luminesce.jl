
function _aug(mode, N)
    length(mode) == N && return mode
    OrderedDict([
        begin
            i = findfirst(keys(mode)) do k
                endswith(string(k), s)
            end
            # @show keys(mode), s, i
            isnothing(i) ? (Symbol("J$s") => 0) : (keys(mode)[i] => mode[keys(mode)[i]])
        end for s = "xyz"[1:N]
    ])
end

"""
"""
struct Source
    λmodenums
    λsmode

    λmodes

    center
    L
    # normal
    # tangent
    # zaxis
    # xaxis
    dimsperm
    N
    approx_2D_mode
    center3
    L3
    tags
    # function Source(sigmodes, center::Base.AbstractVecOrTuple, normal, tangent, lb, ub, ; tags...)
    #     new(f, center, lb, ub, normal, tangent, E2J(mode), tags)
    # end
    # function Source(sigmodes, center::Base.AbstractVecOrTuple, L; tags...)
    #     new(sigmodes, center, -L / 2, L / 2, getdimsperm(L), tags)
    # end

end
Source(args...; λmodenums=nothing, λmodes=nothing, λsmode=nothing, tags...) = Source(λmodenums, λmodes, λsmode, args..., tags)

"""
    function PlaneWave(f, dims; mode...)

Constructs plane wave source

Args
- f: time function
- dims: eg -1 for wave coming from -x face
- mode: which mode to excite & their scaling constants (typically a current source, eg Jz=1)
"""
struct PlaneWave
    λmodes
    dims
    tags
    function PlaneWave(sigmodes, dims; tags...)
        new(sigmodes, dims, tags)
    end
end
@functor PlaneWave
"""
    function GaussianBeam(f, σ, c, dims; mode...)

Constructs gaussian beam source

Args
- f: time function
- σ: std dev length
- dims: eg 1 for x direction
- mode: which mode to excite & their scaling constants (typically a current source, eg Jz=1)
"""
struct GaussianBeam
    f
    σ
    mode
    c
    dims
    function GaussianBeam(f, σ, c, dims; mode...)
        new(f, σ, mode, c, dims)
    end
end
@functor GaussianBeam

"""
    function Source(f, c, lb, ub, tags=""; mode...)
    function Source(f, c, L, tags=""; mode...)
        
Constructs custom  source. Can be used to specify uniform or modal sources

Args
- f: time function
- c: g.lb or center of source
- lb: lower bounds wrt to c
- ub: upper bounds wrt to c
- L: source dimensions in [wavelengths]
- mode: which mode to excite & their scaling constants (typically a current source, eg Jz=1)
"""

# mode(m::Source) = m.mode
# Base.string(m::Union{Source,Source}) =
#     """
#     $(m.tags): $(count((m.ub.-m.lb).!=0))-dimensional source, centered at $(m.center|>d2), spanning from $(m.lb|>d2) to $(m.ub|>d2) relative to center,"""
#  exciting $(join(keys(m.mode),", "))"""


struct SourceInstance
    sigmodes
    # o
    center
    # dimsperm
    tags
end
@functor SourceInstance (sigmodes,)

function SourceInstance(s::PlaneWave, g)
    @unpack L = g
    @unpack dims, sigmodes, tags = s
    SourceInstance(Source(sigmodes, L / 2, -L / 2, L / 2, getdimsperm(dims), tags), g)
end

function SourceInstance(s::Source, g, ϵ, temp, mode_solutions=nothing)
    @unpack dimsperm, N, tags = s
    @unpack F, field_sizes = g
    C = complex(F)
    ϵeff = nothing
    λmodes, roi, _center = _get_λmodes(s, ϵ, temp, mode_solutions, g)


    λs = @ignore_derivatives Array(keys(λmodes))
    modess = values(λmodes)
    iss = cluster(λs)
    sigmodes = map(iss) do is
        f = t -> sum(getindex.((Array(λs),), Array(is))) do λ
            cispi(2t / λ) |> C
        end
        _modess = getindex.((modess,), is)
        modes = _modess[round(length(_modess) / 2 + 0.1)]
        f, modes
    end

    sigmodes = reduce(vcat, [collect(zip(fill(f, length(modes)), modes)) for (f, modes) = sigmodes])
    sigmodes = [
        begin
            _f = if isa(sig, Number)
                t -> cispi(2t / sig)
            else
                sig
            end
            f = x -> convert(C, _f(x))

            mode = NamedTuple([k => v for (k, v) = pairs(mode) if startswith(string(k), "J")])

            mode = permutexyz(mode, invperm(dimsperm), N)
            mode = _aug(mode, N)
            ks = sort([k for k = keys(mode) if string(k)[end] in "xyz"[1:N]])
            _mode = namedtuple([k => begin
                b = mode(k)
                k = Symbol("E$(string(k)[end])")
                a = zeros(C, field_sizes[k])
                if b == 0
                    0
                else
                    I = roi[k]
                    global aaaa = a, b, mode, k, I
                    setindexf!(a, b, I...)
                    a
                end
            end for k = ks])
            (f, _mode)
        end for (sig, mode) = sigmodes
    ]
    # @show center, g.lb, _center

    SourceInstance(sigmodes, _center, tags)
end

# Complex
function (s::SourceInstance)(t::Real)
    namedtuple([
        k => sum(s.sigmodes) do (f, _mode)
            real(f(t) .* _mode[k])
        end for k = keys(s.sigmodes[1][2])])
end

function E2J(d)
    k0 = filter(k -> string(k)[1] == 'E', keys(d))
    k = [Symbol("J" * string(k)[2:end]) for k in k0]
    v = [d[k] for k in k0]
    dict(Pair.(k, v))
end
function EH2JM(d::T) where {T}
    dict(Pair.(replace(keys(d), :Ex => :Jx, :Ey => :Jy, :Ez => :Jz, :Hx => :Mx, :Hy => :My, :Hz => :Mz), values(d)))
end

function _get_λmodes(s, ϵ, temp, mode_solutions, g)
    @unpack center, L, tags, dimsperm, N, center3, L3, approx_2D_mode, λmodenums, λmodes, λsmode = s
    @unpack F, deltas, deltas3, field_sizes, field_lims, mode_spacing, dl = g
    dx = deltas[1][1]

    start = v2i(center - L / 2 - g.lb, deltas)
    stop = v2i(center + L / 2 - g.lb, deltas)
    start, stop = min.(start, stop), max.(start, stop)

    sel = abs.(start - stop) .> 1e-3
    start += 0.5sel
    stop -= 0.5sel
    len = int(stop - start + 1)

    start = F(start)
    stop = F(stop)

    roi = dict([k => begin
        range.(start, stop, len) - lr[:, 1] + 1
    end for (k, lr) = pairs(field_lims)])
    _center = round(v2i(center - g.lb, deltas) + 0.5)

    # 
    if !isnothing(λmodenums)

        start3 = round((center3 - L3 / 2) / dl + 0.001)
        stop3 = round((center3 + L3 / 2) / dl + 0.001)
        start3, stop3 = min.(start3, stop3), max.(start3, stop3)

        sel3 = start3 .!= stop3
        start3 += 0.5sel3
        stop3 -= 0.5sel3

        ratio = int(dx / dl)
        stop3[1:N] = sel3[1:N] .* (ratio * len[1:N] - 1) + start3[1:N]
        len3 = int(stop3 - start3 + 1)

        start3 += 0.5
        stop3 += 0.5

        start3 = F(start3)
        stop3 = F(stop3)

        ϵmode = getindexf(ϵ, range.(start3, stop3, len3)...;)
        global _a = ϵmode, start3, stop3, len3, dimsperm
        ϵmode = permutedims(ϵmode, dimsperm, 2)

        # global _a = ϵmode, dimsperm
        λmodes = OrderedDict([λ => begin
            modes = solvemodes(ϵmode, dl, λ, maximum(mns) + 1, mode_spacing, temp; mode_solutions)[mns+1]
            # if isnothing(ϵeff)
            #     @unpack Ex, Ey = modes[1]
            #     E = sqrt.(abs2.(Ex) + abs2.(Ey))
            #     ϵ = downsample(ϵmode, mode_spacing)
            #     J = sum(ϵ .* E, dims=2)
            #     E = sum(E, dims=2)
            #     ϵ = J ./ E
            #     ϵmin, ϵmax = extrema(ϵmode)
            #     # v = filter(v) do x
            #     #     ϵmin <= x <= ϵmax
            #     # end

            #     # ϵeff = maximum(ϵmode) => ϵ[argmax(E)]
            #     # ϵeff = maximum(ϵmode) => 0.8ϵmax + 0.2ϵmin
            #     ϵeff = maximum(ϵmode) => ϵmax
            # end
            modes
        end for (λ, mns) = pairs(λmodenums)])
        if N == 2
            λmodes = kmap(v -> collapse_mode.(v, approx_2D_mode), λmodes)
        end
    elseif !isnothing(λsmode)
        λs, mode = λsmode
        mode = OrderedDict([
            begin
                if isa(v, Number)
                    v = v * ones(F, len)
                end
                k => v
            end for (k, v) = pairs(mode)
        ])
        λmodes = OrderedDict([λ => mode for λ = λs])
    end
    λmodes = fmap(F, λmodes)

    λmodes = sort(λmodes, by=kv -> kv[1])

    λmodes, roi, _center
end