using CUDA
ArrayPadding.fillfunc(::Type{CuArray}) = CUDA.fill