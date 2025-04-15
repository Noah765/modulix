isNixosSystem: {
  defaultSystem ? "x86_64-linux",
  defaultHmUsername ? null,
  globalModules ? [],
  configurations ? {},
  outputs ? (_: {}),
  ...
} @ config: inputs: let
  inherit (inputs.nixpkgs) lib;
  inherit (lib) all attrNames attrValues concatMapStringsSep elem filter flip foldlAttrs head init isAttrs isFunction isBool isList isString last length mapAttrs throwIfNot unsafeGetAttrPos;

  explicitOutputs = outputs inputs;

  modulixConfigurations = flip mapAttrs configurations (name: x:
    import ./eval-modules.nix {
      system = x.system or defaultSystem;
      modules = [
        {
          _file = (unsafeGetAttrPos "globalModules" config).file;
          imports = x.modules or [] ++ globalModules;
        }
      ];
      prefix = x.prefix or [];
      specialArgs = {
        inherit inputs;
        configName = name;
        useHm = x.useHm or true;
        hmUsername = x.hmUsername or defaultHmUsername;
      };
    });

  nixosConfigurations = flip mapAttrs modulixConfigurations (_: x: {
    inherit (x._module.args) lib pkgs;
    config = x.config.os;
  });

  finalOutputs =
    explicitOutputs
    // {
      inherit modulixConfigurations;
      nixosConfigurations = nixosConfigurations // explicitOutputs.nixosConfigurations or {};
    };

  enumerateList = list: "${concatMapStringsSep ", " (x: "'${x}'") (init list)} and '${last list}'";

  invalidConfigAttrs = filter (x: !elem x ["initialInputs" "defaultSystem" "defaultHmUsername" "globalModules" "configurations" "outputs"]) (attrNames config);
  conflictingNixosConfigurationNames = filter (x: explicitOutputs.nixosConfigurations or {} ? ${x}) (attrNames nixosConfigurations);
  checkedConfig =
    throwIfNot (isList globalModules) "The 'globalModules' attribute of the Modulix config isn't a list."
    throwIfNot (isAttrs configurations && all isAttrs (attrValues configurations)) "The 'configurations' attribute of the Modulix config isn't an attribute set of attribute sets."
    throwIfNot (isFunction outputs) "The 'outputs' attribute of the Modulix config isn't a function."
    throwIfNot (invalidConfigAttrs == [] || length invalidConfigAttrs > 1) "The Modulix config contains an invalid attribute named '${head invalidConfigAttrs}'."
    throwIfNot (invalidConfigAttrs == []) "The Modulix config contains invalid attributes with the following names: ${enumerateList invalidConfigAttrs}."
    throwIfNot (conflictingNixosConfigurationNames == [] || length conflictingNixosConfigurationNames > 1) "The Modulix config named '${head conflictingNixosConfigurationNames}' conflicts with explicitly defined 'nixosConfigurations'."
    throwIfNot (conflictingNixosConfigurationNames == []) "The Modulix configs named ${enumerateList conflictingNixosConfigurationNames} conflict with explicitly defined 'nixosConfigurations'."
    finalOutputs;

  checkedConfigurations =
    foldlAttrs (
      outputs: name: config: let
        configString =
          if isNixosSystem
          then "Modulix 'nixosSystem'"
          else "Modulix config named '${name}'";
        system = config.system or defaultSystem;
        invalidConfigAttrs = filter (x: !elem x ["system" "useHm" "hmUsername" "modules" "prefix"]) (attrNames config);
      in
        throwIfNot (isString system) "The system for the ${configString} isn't a string."
        throwIfNot (elem system lib.systems.flakeExposed) "The system '${system}' defined for the ${configString} is invalid or unsupported."
        throwIfNot (isBool config.useHm or true) "The 'useHm' attribute of the ${configString} isn't a bool."
        throwIfNot (config ? hmUsername || defaultHmUsername != null) "There is no Home Manager username defined for the ${configString}."
        throwIfNot (isString config.hmUsername or defaultHmUsername) "The Home Manager username of the ${configString} isn't a string."
        throwIfNot (isList config.modules or []) "The 'modules' attribute of the ${configString} isn't a list."
        throwIfNot (isList config.prefix or [] && all isString config.prefix or []) "The 'prefix' attribute of the ${configString} isn't a list of strings."
        throwIfNot (invalidConfigAttrs == [] || length invalidConfigAttrs > 1) "The ${configString} contains an invalid attribute named '${head invalidConfigAttrs}'."
        throwIfNot (invalidConfigAttrs == []) "The ${configString} contains invalid attributes with the following names: ${enumerateList invalidConfigAttrs}."
        outputs
    )
    checkedConfig
    configurations;
in
  checkedConfigurations
