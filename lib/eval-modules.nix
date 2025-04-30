{
  system,
  modules,
  prefix ? [],
  specialArgs ? {},
}: let
  inherit (specialArgs) inputs;
  inherit (inputs) nixpkgs home-manager;
  pkgs = nixpkgs.legacyPackages.${system};
  lib = import "${home-manager}/modules/lib/stdlib-extended.nix" ((import (import ./patched-nixpkgs-lib pkgs)).extend (import "${nixpkgs}/lib/flake-version-info.nix" nixpkgs));
  inherit (lib) concatMap concatStringsSep evalModules filter flip isPath mkAliasOptionModule mkOption mkOrder showWarnings throwIfNot;

  allModules = lib.modules.collectModules "modulix" "" modules {
    inherit lib inputs;
    config = null;
  };
  osModules = concatMap (x: x.osImports) allModules;
  hmModules = concatMap (x: x.hmImports) allModules;

  evaluatedModules = evalModules {
    inherit prefix specialArgs;
    class = "modulix";
    modules =
      [
        ({config, ...}: {
          options.os = mkOption {
            type = lib.types.submoduleWith (let
              baseModules = flip map (import "${nixpkgs}/nixos/modules/module-list.nix") (x:
                if isPath x && baseNameOf x == "top-level.nix"
                then "${import ./patched-top-level-module pkgs}/top-level.nix"
                else if isPath x && baseNameOf x == "activatable-system.nix"
                then toString x
                else x);
            in {
              class = "nixos";
              modules = osModules ++ baseModules;
              specialArgs = {
                inherit baseModules;
                modulesPath = "${nixpkgs}/nixos/modules";
              };
            });
            default = {};
            visible = "shallow";
            description = "NixOS configuration.";
          };

          config = {
            _module.args = {
              inherit lib;
              inherit (config.os._modulixArgs) pkgs utils;
            };

            os = {
              _class,
              pkgs,
              utils,
              ...
            }: {
              options._modulixArgs = mkOption {visible = "hidden";};

              config = {
                _modulixArgs = {inherit _class pkgs utils;};

                home-manager = {
                  useGlobalPkgs = true;
                  sharedModules = hmModules;
                };
              };
            };

            nixpkgs.flake.source = nixpkgs.outPath;

            warnings = mkOrder 1600 (map (x: "os: ${x}") config.os.warnings);
            assertions = mkOrder 1600 (flip map config.os.assertions (x: {
              inherit (x) assertion;
              message = "os: ${x.message}";
            }));
          };
        })
        (import ./home-manager-module pkgs home-manager).outPath
        (mkAliasOptionModule ["nixpkgs"] ["os" "nixpkgs"])
        "${nixpkgs}/nixos/modules/misc/assertions.nix"
      ]
      ++ modules;
  };

  failedAssertions = map (x: x.message) (filter (x: !x.assertion) evaluatedModules.config.assertions);
in
  throwIfNot (failedAssertions == []) "\nFailed assertions:\n${concatStringsSep "\n" (map (x: "- ${x}") failedAssertions)}"
  (showWarnings evaluatedModules.config.warnings evaluatedModules)
