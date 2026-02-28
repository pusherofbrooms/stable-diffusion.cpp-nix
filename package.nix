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
  cudaPackages ? null,
  autoAddDriverRunpath ? null,
  src,
  version ? "0.0.0",
  useVulkan ? false,
  useBlas ? false,
  useCuda ? false,
  effectiveStdenv ? if useCuda then cudaPackages.backendStdenv else stdenv,
}:

let
  inherit (lib) cmakeBool cmakeFeature optionals strings;

  suffixes =
    lib.optionals useBlas [ "blas" ]
    ++ lib.optionals useVulkan [ "vulkan" ]
    ++ lib.optionals useCuda [ "cuda" ];

  pnameSuffix =
    strings.optionalString (suffixes != [ ])
      "-${strings.concatMapStringsSep "-" strings.toLower suffixes}";
in
assert (!useCuda || (cudaPackages != null && autoAddDriverRunpath != null));
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
    (cmakeBool "SD_HIPBLAS" false)
    (cmakeBool "SD_METAL" false)
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
  ++ optionals useCuda [
    (
      with cudaPackages.flags;
      cmakeFeature "CMAKE_CUDA_ARCHITECTURES" (
        builtins.concatStringsSep ";" (map dropDot cudaCapabilities)
      )
    )
  ];

  meta = {
    description = "stable-diffusion.cpp CLI/server binaries";
    homepage = "https://github.com/leejet/stable-diffusion.cpp";
    license = lib.licenses.mit;
    mainProgram = "sd-cli";
    platforms = if useCuda then lib.platforms.linux else lib.platforms.unix;
  };
}
