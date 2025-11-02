final: prev:
let
  lib = prev.lib;
  localPackages = (
    lib.packagesFromDirectoryRecursive {
      inherit (final) callPackage newScope;
      directory = ./pkgs;
    }
  );
in
lib.mapAttrs (
  name: pkg:
  if lib.isAttrs pkg then
    (prev.${name} or { }) // pkg
  else if lib.isDerivation pkg then
    pkg
  else
    prev.${name} or pkg
) localPackages
