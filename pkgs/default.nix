{
  pkgs ? import <nixpkgs> { },
  lib ? pkgs.lib,
  ...
}:
let
  capitalize =
    str:
    let
      strList = lib.stringToCharacters str;
    in
    lib.toUpper (builtins.head strList)
    + lib.concatStrings (lib.map lib.toLower (builtins.tail strList));

  toCamelCase =
    str:
    let
      strList = lib.splitString "-" str;
    in
    builtins.head strList + lib.concatStrings (lib.map capitalize (builtins.tail strList));

  packagesPerFileRecursive =
    dir:
    lib.mapAttrs'
      (
        name: type:
        if type == "directory" then
          lib.nameValuePair (toCamelCase name) (packagesPerFileRecursive "${dir}/${name}")
        else
          lib.nameValuePair (lib.removeSuffix ".nix" name) (pkgs.callPackage "${dir}/${name}" { })
      )
      (
        lib.filterAttrs (
          name: type: name != "default.nix" && (type == "directory" || lib.hasSuffix ".nix" name)
        ) (builtins.readDir dir)
      );
in
packagesPerFileRecursive ./.
