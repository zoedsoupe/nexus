{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05-small";
    elixir-overlay.url = "github:zoedsoupe/elixir-overlay";
  };

  outputs = {
    nixpkgs,
    elixir-overlay,
    ...
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
    devShells = forAllSystems (pkgs: let
      inherit (pkgs) mkShell;
      inherit (pkgs.beam.interpreters) erlang_27;
    in {
      default = mkShell {
        name = "nexus";
        packages = with pkgs; [elixir_1_18 erlang_27];
      };
    });
  };
}
