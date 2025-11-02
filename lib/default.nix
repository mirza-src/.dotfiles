{ lib, ... }:
rec {
  isNixFile = filename: lib.hasSuffix ".nix" filename;

  listNixModules =
    dir:
    lib.mapAttrsToList (name: _: lib.removeSuffix ".nix" name) (
      lib.filterAttrs (name: type: name != ".shared" && (type == "directory" || isNixFile name)) (
        builtins.readDir dir
      )
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
