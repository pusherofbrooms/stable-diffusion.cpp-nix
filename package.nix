{
  lib,
  stdenv,
  cmake,
  ninja,
  pkg-config,
  git,
  vulkan-headers,
  vulkan-loader,
  shaderc,
  openblas,
  darwin ? null,
  rocmPackages ? null,
  cudaPackages ? null,
  autoAddDriverRunpath ? null,
  src,
  version ? "0.0.0",
  useVulkan ? false,
  useBlas ? false,
  useMetal ? false,
  useRocm ? false,
  rocmGpuTargets ? if rocmPackages != null then builtins.concatStringsSep ";" rocmPackages.clr.gpuTargets else "",
  useCuda ? false,
  effectiveStdenv ? if useCuda then cudaPackages.backendStdenv else stdenv,
}:

let
  inherit (lib) cmakeBool cmakeFeature optionals strings;

  suffixes =
    lib.optionals useBlas [ "blas" ]
    ++ lib.optionals useMetal [ "metal" ]
    ++ lib.optionals useRocm [ "rocm" ]
    ++ lib.optionals useVulkan [ "vulkan" ]
    ++ lib.optionals useCuda [ "cuda" ];

  pnameSuffix =
    strings.optionalString (suffixes != [ ])
      "-${strings.concatMapStringsSep "-" strings.toLower suffixes}";
in
assert (!useCuda || (cudaPackages != null && autoAddDriverRunpath != null));
assert (!useMetal || stdenv.isDarwin);
assert (!useRocm || (stdenv.isLinux && rocmPackages != null));
assert (!(useCuda && useRocm));
effectiveStdenv.mkDerivation {
  pname = "stable-diffusion-cpp${pnameSuffix}";
  inherit version src;

  nativeBuildInputs = [
    cmake
    ninja
    pkg-config
    git
  ] ++ optionals useCuda [
    cudaPackages.cuda_nvcc
    autoAddDriverRunpath
  ];

  buildInputs =
    optionals useVulkan [
      vulkan-headers
      vulkan-loader
      shaderc
    ]
    ++ optionals (useMetal && stdenv.isDarwin && darwin != null) (with darwin.apple_sdk.frameworks; [
      Foundation
      Metal
      MetalKit
      QuartzCore
    ])
    ++ optionals useRocm (with rocmPackages; [
      clr
      hipblas
      rocblas
    ])
    ++ optionals useBlas [ openblas ]
    ++ optionals useCuda (with cudaPackages; [
      cuda_cudart
      cuda_cccl
      libcublas
    ]);

  cmakeFlags = [
    (cmakeBool "CMAKE_SKIP_BUILD_RPATH" true)
    (cmakeBool "SD_BUILD_EXAMPLES" true)
    (cmakeBool "SD_CUDA" useCuda)
    (cmakeBool "SD_HIPBLAS" useRocm)
    (cmakeBool "SD_METAL" useMetal)
    (cmakeBool "SD_OPENCL" false)
    (cmakeBool "SD_SYCL" false)
    (cmakeBool "SD_MUSA" false)
    (cmakeBool "SD_VULKAN" useVulkan)
    (cmakeBool "GGML_NATIVE" false)
    (cmakeBool "GGML_BLAS" useBlas)
  ]
  ++ optionals useBlas [
    (cmakeFeature "GGML_BLAS_VENDOR" "OpenBLAS")
  ]
  ++ optionals useRocm [
    (cmakeFeature "CMAKE_HIP_COMPILER" "${rocmPackages.llvm.clang}/bin/clang")
    (cmakeFeature "CMAKE_HIP_ARCHITECTURES" rocmGpuTargets)
  ]
  ++ optionals useCuda [
    (
      with cudaPackages.flags;
      cmakeFeature "CMAKE_CUDA_ARCHITECTURES" (
        builtins.concatStringsSep ";" (map dropDot cudaCapabilities)
      )
    )
  ];

  env = lib.optionalAttrs useRocm {
    ROCM_PATH = "${rocmPackages.clr}";
    HIP_DEVICE_LIB_PATH = "${rocmPackages.rocm-device-libs}/amdgcn/bitcode";
  };

  meta = {
    description = "stable-diffusion.cpp CLI/server binaries";
    homepage = "https://github.com/leejet/stable-diffusion.cpp";
    license = lib.licenses.mit;
    mainProgram = "sd-cli";
    platforms = if (useCuda || useRocm) then lib.platforms.linux else lib.platforms.unix;
  };
}
