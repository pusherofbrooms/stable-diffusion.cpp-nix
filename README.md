# stable-diffusion.cpp-nix

External flake packaging for [`stable-diffusion.cpp`](../stable-diffusion.cpp), kept separate from upstream.

## What this flake exposes

### Packages

- `.#default` / `.#cpu` – CPU build (includes `sd-cli` and `sd-server`)
- `.#cpu-blas` – CPU + OpenBLAS
- `.#vulkan` – Vulkan backend build
- `.#cuda` – CUDA backend build (Linux only)
- `.#sd-cli` – slim package with only `sd-cli`
- `.#sd-server` – slim package with only `sd-server`

### Apps

- `.#sd-cli`
- `.#sd-server`

## Common commands

```bash
# inspect outputs
nix flake show

# build CPU package
nix build .#cpu

# build interesting single-binary targets
nix build .#sd-cli
nix build .#sd-server

# run app wrappers
nix run .#sd-cli -- --help
nix run .#sd-server -- --help

# build backend variants
nix build .#vulkan
nix build .#cuda

# enter dev shells
nix develop .#default
nix develop .#vulkan
nix develop .#cuda
```

## Notes

- Source is taken from local path input: `/home/jjorgens/ai/stable-diffusion.cpp`.
- The source filter excludes upstream `build/` to avoid CMake cache conflicts inside Nix builds.
- CUDA output is Linux-gated and uses a CUDA-enabled nixpkgs instance (llama.cpp-style).
