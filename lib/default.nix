{ lib, ... }:
rec {
  capitalize =
    str:
    let
      strList = lib.stringToCharacters str;
    in
    lib.toUpper (builtins.head strList)
    + lib.concatStrings (lib.map lib.toLower (builtins.tail strList));

  uncapitalize =
    str:
    let
      strList = lib.stringToCharacters str;
    in
    lib.toLower (builtins.head strList)
    + lib.concatStrings (lib.map lib.toLower (builtins.tail strList));

  toCamelCase =
    str:
    let
      strList = lib.splitString "-" str;
    in
    builtins.head strList + lib.concatStrings (lib.map capitalize (builtins.tail strList));

  isNixFile = filename: lib.hasSuffix ".nix" filename;

  listNixModules =
    dir:
    lib.mapAttrsToList (name: _: lib.removeSuffix ".nix" name) (
      lib.filterAttrs (name: type: type == "directory" || isNixFile name) (builtins.readDir dir)
    );

  getModulesPerFile =
    dir:
    lib.genAttrs (lib.remove "default" (listNixModules dir)) (module: import "${dir}/${module}.nix");

  createModuleEntryPoint =
    dir:
    let
      modulesPerFile = getModulesPerFile dir;

      default =
        { ... }:
        {
          imports = builtins.attrValues modulesPerFile;
        };
    in
    modulesPerFile // { inherit default; };
}
