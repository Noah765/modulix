{
  description = "Module system for the configuration of flake-based single user NixOS and Home Manager systems";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {nixpkgs, ...}: let
    inherit (nixpkgs) lib legacyPackages;
    forAllSystems = lib.genAttrs lib.systems.flakeExposed;
  in {
    packages = forAllSystems (x: rec {
      mxg = import ./lib/mxg legacyPackages.${x};
      default = mxg;
    });

    modulixSystems = import ./lib/modulix-systems.nix false;
    nixosSystem = config: inputs: (import ./lib/modulix-systems.nix true {configurations.default = config;} inputs).nixosConfigurations.default;

    formatter = forAllSystems (x: legacyPackages.${x}.alejandra);
  };
}
