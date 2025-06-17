{ lib, ... }:
rec {
  listDir = dir: lib.mapAttrsToList (name: _: name) (builtins.readDir dir);

  listNixModules =
    dir:
    lib.mapAttrsToList (name: _: lib.removeSuffix ".nix" name) (
      lib.filterAttrs (name: value: value == "directory" || (builtins.match ".*\\.nix" name != null)) (
        builtins.readDir dir
      )
    );

  listDirectories =
    dir:
    lib.mapAttrsToList (name: _: name) (
      lib.filterAttrs (_: value: value == "directory") (builtins.readDir dir)
    );

  listDirectoryNames = dir: lib.forEach (listDirectories dir) (name: builtins.baseNameOf name);
}
