{
  description = "CLI framework for Elixir, with magic!";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05-small";
    elixir-overlay.url = "github:zoedsoupe/elixir-overlay";
  };

  outputs = {
    self,
    nixpkgs,
    elixir-overlay,
  }: let
    inherit (nixpkgs.lib) genAttrs;
    inherit (nixpkgs.lib.systems) flakeExposed;

    forAllSystems = f:
      genAttrs flakeExposed (
        system: let
          overlays = [elixir-overlay.overlays.default];
          pkgs = import nixpkgs {inherit system overlays;};
        in
          f pkgs
      );
  in {
    devShells = forAllSystems (pkgs: {
      default = pkgs.mkShell {
        name = "nexus-dev";
        packages = with pkgs; [
          (elixir-with-otp erlang_28).latest
          erlang_28
          just
        ];
      };
    });
  };
}
