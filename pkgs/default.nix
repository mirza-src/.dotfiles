{
  pkgs ? import <nixpkgs> { },
  lib ? pkgs.lib,
  ...
}:
lib.packagesFromDirectoryRecursive {
  inherit (pkgs) callPackage newScope;
  directory = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.difference ./. ./default.nix;
  };
}
