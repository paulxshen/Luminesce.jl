var documenterSearchIndex = {"docs":
[{"location":"guide/#","page":"-","title":"","text":"","category":"section"},{"location":"guide/","page":"-","title":"-","text":"Engineers run simulations to improve designs. Each time the design changes, the simulation is re-run. This can be done systematically in \"parameter sweeps\" where different combinations of parameter values are simulated to determine the best design. However, this scales exponentially wrt the number of parameters or DOFs. ","category":"page"},{"location":"guide/#General-workflow","page":"-","title":"General workflow","text":"","category":"section"},{"location":"guide/","page":"-","title":"-","text":"We use gradient descent, the same as in machine learning. In lieu of optimizing neural network parameters, we're optimizing geometry (or source) parameters. In each training iteration, we generate geometry, run the simulation, calculate the objective metric, and do a backward pass to derive the gradient wrt the geometry parameters. We then do a gradient based parameter update in preparation for the next iteration.","category":"page"},{"location":"guide/","page":"-","title":"-","text":"The geometry is thus the first step. It typically has a static component which we can't change such as interfacing waveguides. Then there's a design component which we can change or optimize. The user is responsible for generating the design geometry wrt design parameters. If any pattern is allowed in the design region, our sister package Jello.jl can be used as a length scale controlled geometry generator. In any case, the result needs to be a 2d/3d array of each relevant materials property eg permitivity. ","category":"page"},{"location":"guide/","page":"-","title":"-","text":"With geometry ready, we can run the simulation. Duration is roughly the time it takes to reach steady state, such as how long it take for the signal to reach output port. The objective is usually a steady state metric which can be computed using values from the final period.  We optimize geometry for some objective. ","category":"page"},{"location":"#FDTDEngine.jl","page":"FDTDEngine.jl","title":"FDTDEngine.jl","text":"","category":"section"},{"location":"","page":"FDTDEngine.jl","title":"FDTDEngine.jl","text":"First stable release with GPU support planned for end of 02/2024. Currently Prerelease. Expect breaking changes  Only 3d works in latest patch. 2d/1d will be fixed in future.","category":"page"},{"location":"#Overview","page":"FDTDEngine.jl","title":"Overview","text":"","category":"section"},{"location":"","page":"FDTDEngine.jl","title":"FDTDEngine.jl","text":"Differentiable FDTD package for inverse design & topology optimization in photonics, acoustics and RF. Uses automatic differentiation by Zygote.jl for adjoint optimization. Integrates with Jello.jl to generate length scale controlled paramaterized geometry . Staggered Yee grid update with fully featured boundary conditions & sources. Customizable physics to potentially incorporate dynamics like heat transfer, charge transport.","category":"page"},{"location":"#Gallery","page":"FDTDEngine.jl","title":"Gallery","text":"","category":"section"},{"location":"#Periodic-scattering","page":"FDTDEngine.jl","title":"Periodic scattering","text":"","category":"section"},{"location":"","page":"FDTDEngine.jl","title":"FDTDEngine.jl","text":"(Image: )","category":"page"},{"location":"#Quarter-wavelength-antenna","page":"FDTDEngine.jl","title":"Quarter wavelength antenna","text":"","category":"section"},{"location":"","page":"FDTDEngine.jl","title":"FDTDEngine.jl","text":"(Image: )","category":"page"},{"location":"#Inverse-design-of-compact-silicon-photonic-splitter-(coming-soon)","page":"FDTDEngine.jl","title":"Inverse design of compact silicon photonic splitter (coming soon)","text":"","category":"section"},{"location":"#Quickstart","page":"FDTDEngine.jl","title":"Quickstart","text":"","category":"section"},{"location":"","page":"FDTDEngine.jl","title":"FDTDEngine.jl","text":"We do a quick 3d simulation of plane wave scattering on periodic array of dielectric spheres (first gallery movie)","category":"page"},{"location":"","page":"FDTDEngine.jl","title":"FDTDEngine.jl","text":"using UnPack, LinearAlgebra, GLMakie\nusing FDTDEngine,FDTDToolkit\n\nname = \"3d_scattering\"\nT = 8.0f0 # simulation duration in [periods]\nnres = 16\ndx = 1.0f0 / nres # pixel resolution in [wavelengths]\n\n\"geometry\"\nl = 2 # domain physical size length\nsz = nres .* (l, l, l) # domain voxel dimensions\nϵ1 = ϵmin = 1 #\nϵ2 = 2.25f0 # \nb = F.([norm(v .- sz ./ 2) < 0.5 / dx for v = Base.product(Base.oneto.(sz)...)]) # sphere\nϵ = ϵ2 * b + ϵ1 * (1 .- b)\n\n\"setup\"\nboundaries = [Periodic(2), Periodic(3)]# unspecified boundaries default to PML\nsources = [\n    PlaneWave(t -> cos(F(2π) * t), -1; Jz=1) # Jz excited plane wave from -x plane (eg -1)\n]\nn = [1, 0, 0] # normal \nδ = 0.2f0 # margin\n# A = (l - δ)^2\nlm = 1 # monitor side length\nmonitors = [\n    Monitor([δ, l / 2, l / 2], [0, lm, lm], n,), # (center, dimensions, normal)\n    Monitor([l - δ, l / 2, l / 2], [0, lm, lm], n,),\n]\nconfigs = setup(boundaries, sources, monitors, dx, sz; ϵmin, T)\n@unpack μ, σ, σm, dt, geometry_padding, geometry_splits, field_padding, source_instances, monitor_instances, u0, = configs\n\nϵ, μ, σ, σm = apply(geometry_padding; ϵ, μ, σ, σm)\np = apply(geometry_splits; ϵ, μ, σ, σm)\n\n\n# run simulation\nt = 0:dt:T\nu = similar([u0], length(t))\n@showtime u = accumulate!((u, t) -> step!(u, p, t, dx, dt, field_padding, source_instances), u, t, init=deepcopy(u0))\ny = hcat([power.((m,), u) for m = monitor_instances]...)\n\n# make movie\nEz = map(u) do u\n    u[1][3]\nend\nϵz = p[1][3]\ndir = @__DIR__\n\nrecordsim(\"$dir/$(name)_nres_$nres.mp4\", Ez, y;\n    dt,\n    monitor_instances,\n    source_instances,\n    geometry=ϵz,\n    elevation=30°,\n    playback=1,\n    axis1=(; title=\"$name\\nEz\"),\n    axis2=(; title=\"monitor powers\"),\n)","category":"page"},{"location":"#Installation","page":"FDTDEngine.jl","title":"Installation","text":"","category":"section"},{"location":"","page":"FDTDEngine.jl","title":"FDTDEngine.jl","text":"Install via ","category":"page"},{"location":"","page":"FDTDEngine.jl","title":"FDTDEngine.jl","text":"Pkg.add(url=\"https://github.com/paulxshen/FDTDEngine.jl\")\nPkg.add(url=\"https://github.com/paulxshen/FDTDToolkit.jl\")","category":"page"},{"location":"","page":"FDTDEngine.jl","title":"FDTDEngine.jl","text":"FDTDToolkit.jl contains visualization utilities","category":"page"},{"location":"#Implementation","page":"FDTDEngine.jl","title":"Implementation","text":"","category":"section"},{"location":"","page":"FDTDEngine.jl","title":"FDTDEngine.jl","text":"Supports 1d (Ez, Hy), 2d TMz (Ez, Hx, Hy), 2d TEz (Hz, Ex, Ey) and 3d. Length and time are in units of wavelength and period. This normalization allows usage of relative  permitivity and permeability  in equations . Fields including electric, magnetic and current density are simply bundled as a vector of vectors of arrays . Boundary conditions pad the field arrays . PML paddings are multilayered, while All other boundaries add single layers. Paddings are stateful and permanent, increasing the size of field and geometry arrays.  Finite differencing happens every update step and are coordinated to implictly implement a staggered Yee's grid .","category":"page"},{"location":"#Sources","page":"FDTDEngine.jl","title":"Sources","text":"","category":"section"},{"location":"","page":"FDTDEngine.jl","title":"FDTDEngine.jl","text":"If a source has fewer nonzero dimensions than the simulation domain, its signal will get normalized along its singleton dimensions. For example, all planar sources in 3d or line sources in 2d will get scaled up by a factor of 1/dx. This way, discretisation would not affect radiated power.","category":"page"},{"location":"","page":"FDTDEngine.jl","title":"FDTDEngine.jl","text":"PlaneWave\nSource","category":"page"},{"location":"#PlaneWave","page":"FDTDEngine.jl","title":"PlaneWave","text":"function PlaneWave(f, dims; fields...)\n\nConstructs plane wave source\n\nArgs\n\nf: time function\ndims: eg -1 for wave coming from -x face\nfields: which fields to excite & their scaling constants (typically a current source, eg Jz=1)\n\n\n\n\n\n","category":"type"},{"location":"#Source","page":"FDTDEngine.jl","title":"Source","text":"function Source(f, c, lb, ub, label=\"\"; fields...)\nfunction Source(f, c, L, label=\"\"; fields...)\n\nConstructs custom  source. Can be used to specify uniform or modal sources\n\nArgs\n\nf: time function\nc: origin or center of source\nlb: lower bounds wrt to c\nub: upper bounds wrt to c\nL: source dimensions in [wavelengths]\nfields: which fields to excite & their scaling constants (typically a current source, eg Jz=1)\n\n\n\n\n\n","category":"type"},{"location":"","page":"FDTDEngine.jl","title":"FDTDEngine.jl","text":"<!– GaussianBeam –>","category":"page"},{"location":"#Boundaries","page":"FDTDEngine.jl","title":"Boundaries","text":"","category":"section"},{"location":"","page":"FDTDEngine.jl","title":"FDTDEngine.jl","text":"Unspecified boundaries default to PML ","category":"page"},{"location":"","page":"FDTDEngine.jl","title":"FDTDEngine.jl","text":"Periodic\nPML\nPEC\nPMC","category":"page"},{"location":"#Periodic","page":"FDTDEngine.jl","title":"Periodic","text":"Periodic(dims)\n\nperiodic boundary\n\n\n\n\n\n","category":"type"},{"location":"#PML","page":"FDTDEngine.jl","title":"PML","text":"function PML(dims, d=0.25f0, σ=20.0f0)\n\nConstructs perfectly matched layers (PML aka ABC, RBC) boundary of depth d wavelengths  Doesn't need to be explictly declared as all unspecified boundaries default to PML\n\n\n\n\n\n","category":"type"},{"location":"#PEC","page":"FDTDEngine.jl","title":"PEC","text":"PEC(dims)\n\nperfect electrical conductor dims: eg -1 for -x side\n\n\n\n\n\n","category":"type"},{"location":"#PMC","page":"FDTDEngine.jl","title":"PMC","text":"PMC(dims)\n\nperfect magnetic conductor\n\n\n\n\n\n","category":"type"},{"location":"#Monitors","page":"FDTDEngine.jl","title":"Monitors","text":"","category":"section"},{"location":"","page":"FDTDEngine.jl","title":"FDTDEngine.jl","text":"Monitor\npower\npower_density","category":"page"},{"location":"#Monitor","page":"FDTDEngine.jl","title":"Monitor","text":"function Monitor(c, L, n=nothing)\n\nConstructs monitor which can span a point, line, surface, or volume monitoring fields or power\n\nArgs\n\nc: origin or center of monitor\nL: physical dimensions of monitor\nn: flux monitor direction (eg normal to flux surface)\n\n\n\n\n\n","category":"type"},{"location":"#power","page":"FDTDEngine.jl","title":"power","text":"function power(m::MonitorInstance, u)\n\ntotal power (Poynting flux) passing thru monitor surface\n\n\n\n\n\n","category":"function"},{"location":"#power_density","page":"FDTDEngine.jl","title":"power_density","text":"function power_density(m::MonitorInstance, u)\n\npower density (avg Poynting flux) passing thru monitor surface\n\n\n\n\n\n","category":"function"},{"location":"#Physics","page":"FDTDEngine.jl","title":"Physics","text":"","category":"section"},{"location":"","page":"FDTDEngine.jl","title":"FDTDEngine.jl","text":"step3!","category":"page"},{"location":"#step3!","page":"FDTDEngine.jl","title":"step3!","text":"function step3(u, p, t, field_padding, source_instances)\n\nUpdates fields for 3d\n\n\n\n\n\n","category":"function"},{"location":"","page":"FDTDEngine.jl","title":"FDTDEngine.jl","text":"<!– step1 –> <!– stepTMz –> <!– stepTEz –>","category":"page"},{"location":"#Automatic-differentiation-adjoints","page":"FDTDEngine.jl","title":"Automatic differentiation adjoints","text":"","category":"section"},{"location":"","page":"FDTDEngine.jl","title":"FDTDEngine.jl","text":"Compatible with Zygote.jl and Flux.jl","category":"page"},{"location":"#Tutorials","page":"FDTDEngine.jl","title":"Tutorials","text":"","category":"section"},{"location":"","page":"FDTDEngine.jl","title":"FDTDEngine.jl","text":"see examples/","category":"page"},{"location":"#Generative-inverse-design","page":"FDTDEngine.jl","title":"Generative inverse design","text":"","category":"section"},{"location":"","page":"FDTDEngine.jl","title":"FDTDEngine.jl","text":"Please contact us for latest scripts.","category":"page"},{"location":"#Comparison-with-other-FDTD-software","page":"FDTDEngine.jl","title":"Comparison with other FDTD software","text":"","category":"section"},{"location":"","page":"FDTDEngine.jl","title":"FDTDEngine.jl","text":"Our focus is on inverse design and topology optimization using adjoints from automatic differentiation. We love a streamlined API backed by a clear, concise and extensible codebase. Attention is paid to speed and malloc but that's not our main concern.","category":"page"},{"location":"#Community","page":"FDTDEngine.jl","title":"Community","text":"","category":"section"},{"location":"","page":"FDTDEngine.jl","title":"FDTDEngine.jl","text":"Discussion & updates at Julia Discourse","category":"page"},{"location":"#Contributors","page":"FDTDEngine.jl","title":"Contributors","text":"","category":"section"},{"location":"","page":"FDTDEngine.jl","title":"FDTDEngine.jl","text":"Paul Shen <pxshen@alumni.stanford.edu>","category":"page"},{"location":"","page":"FDTDEngine.jl","title":"FDTDEngine.jl","text":"2024 (c) Paul Shen","category":"page"}]
}
