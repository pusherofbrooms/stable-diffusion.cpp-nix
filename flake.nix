{
  description = "External flake for stable-diffusion.cpp";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    # Upstream stable-diffusion.cpp source (with submodules)
    sdcpp = {
      url = "git+https://github.com/leejet/stable-diffusion.cpp.git?submodules=1";
      flake = false;
    };
  };

  outputs =
    {
      nixpkgs,
      flake-utils,
      sdcpp,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };
        isDarwin = pkgs.stdenv.isDarwin;
        isLinux = pkgs.stdenv.isLinux;
        isX86_64Linux = system == "x86_64-linux";

        pkgsCuda =
          if isLinux then
            import nixpkgs {
              inherit system;
              config.cudaSupport = true;
              config.allowUnfreePredicate =
                p:
                builtins.all (
                  license:
                  license.free
                  || builtins.elem license.shortName [
                    "CUDA EULA"
                    "cuDNN EULA"
                  ]
                ) (pkgs.lib.toList (p.meta.licenses or p.meta.license));
            }
          else
            null;

        pkgsRocm =
          if isX86_64Linux then
            import nixpkgs {
              inherit system;
              config.rocmSupport = true;
            }
          else
            null;

        src = pkgs.lib.cleanSourceWith {
          src = sdcpp.outPath;
          filter = path: type:
            let
              base = baseNameOf path;
            in
            !(base == "build" || base == ".git" || base == "result");
        };

        mkSd =
          pkgSet: args:
          pkgSet.callPackage ./package.nix (
            {
              inherit src;
              version = "0.0.0";
            }
            // args
          );

        cpu = mkSd pkgs { };
        cpuBlas = mkSd pkgs { useBlas = true; };
        metal = if isDarwin then mkSd pkgs { useMetal = true; } else null;
        vulkan = mkSd pkgs { useVulkan = true; };
        rocm = if isX86_64Linux then mkSd pkgsRocm { useRocm = true; } else null;
        cuda = if isLinux then mkSd pkgsCuda { useCuda = true; } else null;

        defaultBackend = if isDarwin then metal else cpu;

        mkSingleBin =
          name: fromPkg:
          pkgs.runCommand name { } ''
            mkdir -p $out/bin
            ln -s ${fromPkg}/bin/${name} $out/bin/${name}
          '';

        cli = mkSingleBin "sd-cli" defaultBackend;
        server = mkSingleBin "sd-server" defaultBackend;
      in
      {
        packages =
          {
            default = defaultBackend;
            cpu = cpu;
            cpu-blas = cpuBlas;
            vulkan = vulkan;

            "sd-cli" = cli;
            "sd-server" = server;
          }
          // pkgs.lib.optionalAttrs isDarwin {
            inherit metal;
          }
          // pkgs.lib.optionalAttrs isX86_64Linux {
            inherit rocm;
          }
          // pkgs.lib.optionalAttrs isLinux {
            inherit cuda;
          };

        apps = {
          sd-cli = {
            type = "app";
            program = "${cli}/bin/sd-cli";
          };
          sd-server = {
            type = "app";
            program = "${server}/bin/sd-server";
          };
        };

        checks =
          {
            cpu = cpu;
            "cpu-blas" = cpuBlas;
            vulkan = vulkan;
            "sd-cli" = cli;
            "sd-server" = server;
          }
          // pkgs.lib.optionalAttrs isDarwin {
            inherit metal;
          }
          // pkgs.lib.optionalAttrs isX86_64Linux {
            inherit rocm;
          }
          // pkgs.lib.optionalAttrs isLinux {
            inherit cuda;
          };

        devShells =
          {
            default = pkgs.mkShell {
              inputsFrom = [ cpu ];
              packages = with pkgs; [
                cmake
                ninja
                pkg-config
                git
              ];
            };

            vulkan = pkgs.mkShell {
              inputsFrom = [ vulkan ];
              packages = with pkgs; [
                cmake
                ninja
                pkg-config
                git
              ];
            };
          }
          // pkgs.lib.optionalAttrs isDarwin {
            metal = pkgs.mkShell {
              inputsFrom = [ metal ];
              packages = with pkgs; [
                cmake
                ninja
                pkg-config
                git
              ];
            };
          }
          // pkgs.lib.optionalAttrs isX86_64Linux {
            rocm = pkgs.mkShell {
              inputsFrom = [ rocm ];
              packages = with pkgsRocm; [
                cmake
                ninja
                pkg-config
                git
              ];
            };
          }
          // pkgs.lib.optionalAttrs isLinux {
            cuda = pkgs.mkShell {
              inputsFrom = [ cuda ];
              packages = with pkgsCuda; [
                cmake
                ninja
                pkg-config
                git
              ];
            };
          };
      }
    );
}
