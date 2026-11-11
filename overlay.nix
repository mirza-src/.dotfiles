inputs: final: prev:
let
  inherit (prev) lib;
  localPackages = lib.packagesFromDirectoryRecursive {
    inherit (final) callPackage newScope;
    directory = ./pkgs;
  };

  # Kernel modules from ./pkgs-kernel, as an extension for a kernel package set
  # (linuxPackages.extend pkgs.kernelModules). Same layout as ./pkgs, but
  # called with the kernel set's scope (kernel, kernelModuleMakeFlags, ...).
  kernelModules =
    kself: _:
    lib.packagesFromDirectoryRecursive {
      inherit (kself) callPackage;
      newScope = extra: final.newScope (kself // extra);
      directory = ./pkgs-kernel;
    };
in
# Local packages replace nixpkgs' of the same name; local package sets (e.g.
# giantswarm, dms-plugins) are merged into nixpkgs' set of that name, if any.
# The scope's own functions (callPackage, newScope, overrideScope, ...) are
# dropped so they don't shadow nixpkgs'.
lib.pipe localPackages [
  (lib.filterAttrs (_: lib.isAttrs))
  (lib.mapAttrs (name: pkg: if lib.isDerivation pkg then pkg else (prev.${name} or { }) // pkg))
]
// {
  inherit kernelModules;
}
