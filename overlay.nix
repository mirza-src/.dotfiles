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
# Names come from the directory listing, not from localPackages: an overlay's
# attribute names must not depend on evaluating packages built from `final`
# (infinite recursion), and this also leaves out the scope's own functions
# (callPackage, newScope, overrideScope, ...).
lib.pipe (builtins.readDir ./pkgs) [
  (lib.filterAttrs (name: type: type == "directory" || lib.hasSuffix ".nix" name))
  (lib.mapAttrs' (
    name: _:
    let
      attr = lib.removeSuffix ".nix" name;
      pkg = localPackages.${attr};
    in
    lib.nameValuePair attr (if lib.isDerivation pkg then pkg else (prev.${attr} or { }) // pkg)
  ))
]
// {
  inherit kernelModules;
}
