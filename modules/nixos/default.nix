{ self, lib, ... }:
let
  modulesPerFile = lib.genAttrs (lib.remove "default" (self.lib.listNixModules ./.)) (
    module: import ./${module}.nix
  );

  default =
    { ... }:
    {
      imports = builtins.attrValues modulesPerFile;
    };
in
modulesPerFile // { inherit default; }
