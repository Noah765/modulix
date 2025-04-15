pkgs:
pkgs.applyPatches {
  name = "patched-top-level-module";
  src = "${pkgs.path}/nixos/modules/system/activation/top-level.nix";
  unpackCmd = "mkdir src; cp $curSrc src";
  patches = [./patch.patch];
}
