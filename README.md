# flux-zig

⚡ **Fastest FLUX VM** — 210ns/iter, nearly 2x faster than the C VM.

Comptime-optimized bytecode interpreter written in Zig for ARM64 and x86_64.

## Performance (Factorial, 100K iterations)

| Runtime | ns/iter | Notes |
|---------|---------|-------|
| **Zig (ReleaseFast)** | **210** | ⚡ Fastest |
| JavaScript (V8) | 373 | JIT magic |
| C (-O2) | 403 | Solid baseline |

## Building & Running

```bash
zig build-exe src/main.zig -OReleaseFast -femit-bin=flux-zig
./flux-zig
```

## Part of the FLUX Ecosystem
- [flux-runtime](https://github.com/SuperInstance/flux-runtime) — Python (1944 tests)
- [flux-core](https://github.com/SuperInstance/flux-core) — Rust
- [flux-js](https://github.com/SuperInstance/flux-js) — JavaScript
- [flux-benchmarks](https://github.com/SuperInstance/flux-benchmarks) — Performance data
- [flux-research](https://github.com/SuperInstance/flux-research) — Architecture docs
