pkgs: home-manager:
pkgs.applyPatches {
  name = "home-manager-module";
  src = "${home-manager}/nixos";
  patches = [./patch.patch];
}
