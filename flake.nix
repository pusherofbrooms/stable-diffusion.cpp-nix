{
  description = "External flake for stable-diffusion.cpp";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    # Local upstream checkout (with ggml submodule present)
    sdcpp = {
      url = "path:/home/jjorgens/ai/stable-diffusion.cpp";
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

        pkgsCuda =
          if pkgs.stdenv.isLinux then
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
        vulkan = mkSd pkgs { useVulkan = true; };
        cuda = if pkgs.stdenv.isLinux then mkSd pkgsCuda { useCuda = true; } else null;

        mkSingleBin =
          name: fromPkg:
          pkgs.runCommand name { } ''
            mkdir -p $out/bin
            ln -s ${fromPkg}/bin/${name} $out/bin/${name}
          '';

        cli = mkSingleBin "sd-cli" cpu;
        server = mkSingleBin "sd-server" cpu;
      in
      {
        packages =
          {
            default = cpu;
            cpu = cpu;
            cpu-blas = cpuBlas;
            vulkan = vulkan;

            "sd-cli" = cli;
            "sd-server" = server;
          }
          // pkgs.lib.optionalAttrs pkgs.stdenv.isLinux {
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

        checks = {
          inherit cpu;
          "sd-cli" = cli;
          "sd-server" = server;
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
          // pkgs.lib.optionalAttrs pkgs.stdenv.isLinux {
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
