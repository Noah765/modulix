pkgs:
pkgs.applyPatches {
  name = "patched-nixpkgs-lib";
  src = "${pkgs.path}/lib";
  patches = [./patch.patch];
  postPatch = "rm -r tests";
}
