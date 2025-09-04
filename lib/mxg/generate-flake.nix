{
  libPath,
  configPath,
  autogenerationWarning,
}: let
  lib = import libPath;
  inherit (lib) all attrNames attrValues concatMap concatStringsSep filterAttrs flip foldl foldlAttrs head isAttrs isString length mapAttrs optional sort throwIfNot;

  config = import configPath;

  initialInputDefs = optional (config ? initialInputs) {
    file = configPath;
    value = config.initialInputs;
  };

  directConfigModules = foldlAttrs (modules: _: config: modules ++ config.modules) config.globalModules or [] config.configurations or {};
  configModules =
    (lib.modules.collectModules "modulix" "" directConfigModules {
      inherit lib;
      config = null;
    }).modules;
  configInputDefs = flip concatMap configModules (x:
    optional (x ? inputs) {
      file = x._file;
      value = x.inputs;
    });

  inputDefs = initialInputDefs ++ configInputDefs;
  wrongTypeInputDefs = flip concatMap inputDefs (x:
    if !isAttrs x.value
    then [x]
    else if !all isAttrs (attrValues x.value)
    then [(x // {value = filterAttrs (_: x: !isAttrs x) x.value;})]
    else []);
  typeCheckedInputDefs = throwIfNot (wrongTypeInputDefs == []) "Flake inputs should be attribute sets. Given values:${lib.options.showDefs wrongTypeInputDefs}" inputDefs;

  inputValues = foldl (inputs: def: inputs // def.value) {} typeCheckedInputDefs;
  duplicationCheckedInputs = flip mapAttrs inputValues (
    name: value: let
      defs = concatMap (x: optional (x.value ? ${name}) (x // {value = x.value.${name};})) inputDefs;
    in
      throwIfNot (all (def: def.value == (head defs).value) defs) "The flake input '${name}' has conflicting definition values:${lib.options.showDefs defs}" value
  );

  inputs =
    {
      nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
      home-manager = {
        url = "github:nix-community/home-manager";
        inputs.nixpkgs.follows = "nixpkgs";
      };
      modulix = {
        url = "github:Noah765/modulix";
        inputs = {
          home-manager.follows = "home-manager";
          nixpkgs.follows = "nixpkgs";
        };
      };
    }
    // duplicationCheckedInputs;

  prettyPrint = depth: x:
    if isAttrs x
    then let
      prefix = lib.strings.replicate depth "  ";
    in
      "{\n${prefix}  "
      + concatStringsSep "\n${prefix}  " (map (name: prettyPrintAttr (depth + 1) name x.${name}) (
        if depth == 2
        then sortInputAttrNames (attrNames x)
        else attrNames x
      ))
      + "\n${prefix}}"
    else if isString x
    then "\"${x}\""
    else if x == true
    then "true"
    else if x == false
    then "false"
    else toString x;
  prettyPrintAttr = depth: name: value:
    if isAttrs value && length (attrNames value) == 1
    then "${name}.${prettyPrintAttr depth (head (attrNames value)) (head (attrValues value))}"
    else "${name} = ${prettyPrint depth value};";

  inputAttrOrder = ["url" "type" "path" "owner" "repo" "ref" "rev" "dir" "inputs"];
  sortInputAttrNames = x:
    sort (
      a: b: let
        aIndex = lib.lists.findFirstIndex (x: x == a) null inputAttrOrder;
        bIndex = lib.lists.findFirstIndex (x: x == b) null inputAttrOrder;
      in
        if aIndex == null || bIndex == null
        then aIndex != null
        else aIndex < bIndex
    )
    x;
in ''
  ${autogenerationWarning}
  {
    ${prettyPrintAttr 1 "inputs" inputs}

    outputs = inputs: inputs.modulix.modulixSystems (import ./config.nix) inputs;
  }
''
