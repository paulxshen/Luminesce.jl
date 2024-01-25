@load "$(@__DIR__)/model" model0 model
T = 16
p0 = make_geometry(model0, μ, σ, σm)
p = make_geometry(model, μ, σ, σm)
@showtime sol0 = accumulate((u, t) -> step3(u, p0, t, configs), 0:dt:T, init=u0)
@showtime sol = accumulate((u, t) -> step3(u, p, t, configs), 0:dt:T, init=u0)
@showtime savesim(sol0, p0, "pre_training")
savesim(sol, p, "post_training")

f = Figure()
a, = volume(f[1, 1], ones(2, 2, 2))
rotate_cam!(a.scene, 45, 5, 5)