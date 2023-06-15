{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-22.11";

  outputs = { self, nixpkgs }:
    let
      systems = {
        linux = "x86_64-linux";
        darwin = "aarch64-darwin";
      };

      pkgs = system: import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };

      inputs = sys: with pkgs sys; [
        elixir_1_14
      ] ++ lib.optional stdenv.isLinux [
        inotify-tools
        gtk-engine-murrine
      ] ++ lib.optional stdenv.isDarwin [
        darwin.apple_sdk.frameworks.CoreServices
        darwin.apple_sdk.frameworks.CoreFoundation
      ];

      name = "nexus";
    in {
      applications."${systems.linux}".pescarte =
        let
          inherit (pkgs systems.linux) beam callPackage;
          beamPackages = beam.packagesWith beam.interpreters.erlang;
        in beamPackages.mixRelease rec {
          pname = name;
          version = "0.1.0";
          src = ./.;
          postBuild = "mix do deps.loadpaths --no-deps-check";
          mixFodDeps = beamPackages.fetchMixDeps {
            inherit src version;
            pname = "mix-deps-${pname}";
            sha256 = "";
          };
        };

      devShells = {
        "${systems.linux}".default = with pkgs systems.linux; mkShell {
          inherit name;
          buildInputs = inputs systems.linux;
        };

        "${systems.darwin}".default = with pkgs systems.darwin; mkShell {
          inherit name;
          buildInputs = inputs systems.darwin;
        };
      };
    };
}
