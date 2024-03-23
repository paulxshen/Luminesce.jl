"""
simulation of plane wave scattering on periodic array of dielectric spheres
"""

using UnPack, LinearAlgebra, GLMakie
using Luminescent, LuminescentVisualization

# # if running directly without module
# dir = pwd()
# include("$(dir)/src/main.jl")
# include("$dir/../LuminescentVisualization.jl/src/main.jl")

dogpu = false
F = Float32
name = "periodic_scattering"
T = 10 # simulation duration in [periods]
nx = 20
dx = 1.0 / nx # pixel resolution in [wavelengths]

# geometry
l = 2 # domain physical size length in [wavelengths]
sz = nx .* (l, l, l) # domain voxel dimensions
ϵ1 = ϵmin = 1 #
ϵ2 = 2.25 # 
b = F.([norm(port_powers .- sz ./ 2) < 0.5 / dx for port_powers = Base.product(Base.oneto.(sz)...)]) # sphere
ϵ = ϵ2 * b + ϵ1 * (1 .- b)
μ = 1
σ = zeros(F, sz)
σm = zeros(F, sz)

# maxwell_setup
boundaries = [Periodic(2), Periodic(3)]# unspecified boundaries default to PML
sources = [
    PlaneWave(t -> cos(2π * t), -1; Jz=1) # Jz excited plane wave from -x plane (eg -1)
]
normal = [1, 0, 0] #  
δ = 0.2 # margin
lm = 1 # monitor side length
monitors = [
    Monitor([δ, l / 2, l / 2], [0, lm, lm]; normal), # (center, dimensions; normal)
    Monitor([l - δ, l / 2, l / 2], [0, lm, lm]; normal),
]
configs = maxwell_setup(boundaries, sources, monitors, dx, sz; ϵmin, F)
@unpack dt, geometry_padding, geometry_staggering, field_padding, source_instances, monitor_instances, u0, = configs

p = apply(geometry_padding; ϵ, μ, σ, σm)
p = apply(geometry_staggering; p...)

# move to gpu
if dogpu
    using CUDA, Flux
    @assert CUDA.functional()
    u0, p, field_padding, source_instances = gpu.((u0, p, field_padding, source_instances))
end

# run simulation
@showtime u = accumulate(0:dt:T, init=u0) do u, t
    maxwell_update!(deepcopy(u), p, t, dx, dt, field_padding, source_instances)
end
port_powers = [power_flux.(u, (m,),) for m = monitor_instances]

# move back to cpu for plotting
if dogpu
    u, p, field_padding, source_instances = cpu.((u, p, field_padding, source_instances))
end

# make movie, 
Ez = field.(u, :Ez)
ϵEz = field(p, :ϵEz)
dir = @__DIR__
recordsim("$dir/$(name).mp4", Ez, port_powers;
    dt,
    field=:Ez,
    monitor_instances,
    source_instances,
    geometry=ϵEz,
    elevation=30°,
    playback=1,
    axis1=(; title="$name"),
    axis2=(; title="monitor powers"),
)
