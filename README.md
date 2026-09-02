# stable-diffusion.cpp-nix

External flake packaging for [`stable-diffusion.cpp`](https://github.com/leejet/stable-diffusion.cpp), kept separate from upstream.

## What this flake exposes

### Packages

- `.#default` – default backend build (`metal` on macOS, `cpu` elsewhere; includes `sd-cli` and `sd-server`)
- `.#cpu` – CPU build
- `.#cpu-blas` – CPU + OpenBLAS
- `.#metal` – Metal backend build (macOS only)
- `.#vulkan` – Vulkan backend build
- `.#rocm` – ROCm/HIP backend build (x86_64 Linux only)
- `.#cuda` – CUDA backend build (Linux only)
- `.#sd-cli` – convenience package exposing only the `sd-cli` command
- `.#sd-server` – convenience package exposing only the `sd-server` command

### Apps

- `.#sd-cli` (built from `.#default`: Metal on macOS, CPU elsewhere)
- `.#sd-server` (built from `.#default`: Metal on macOS, CPU elsewhere)

## Common commands

```bash
# inspect outputs
nix flake show

# build default package (Metal on macOS, CPU elsewhere)
nix build .#default

# build CPU package explicitly
nix build .#cpu

# build interesting single-binary targets
nix build .#sd-cli
nix build .#sd-server

# run app wrappers
nix run .#sd-cli -- --help
nix run .#sd-server -- --help

# build backend variants
nix build .#metal
nix build .#vulkan
nix build .#rocm
nix build .#cuda

# enter dev shells
nix develop .#default
nix develop .#metal
nix develop .#vulkan
nix develop .#rocm
nix develop .#cuda
```

## Notes

- Source is taken from upstream Git input: `git+https://github.com/leejet/stable-diffusion.cpp.git?submodules=1`.
- The source filter excludes upstream `build/` to avoid CMake cache conflicts inside Nix builds.
- Metal output is Darwin-gated.
- ROCm output is gated to `x86_64-linux` and uses a ROCm-enabled nixpkgs instance (llama.cpp-style).
- CUDA output is Linux-gated and uses a CUDA-enabled nixpkgs instance (llama.cpp-style).
