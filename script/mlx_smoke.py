import mlx.core as mx

print(f"mlx_version={mx.__version__}")
print(f"default_device={mx.default_device()}")
print(f"metal_available={mx.metal.is_available()}")

x = mx.array([1.0, 2.0, 3.0])
y = x * 2
mx.eval(y)
print(f"result={y.tolist()}")
