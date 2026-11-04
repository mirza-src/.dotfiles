{ self, ... }:
let
  modules = self.lib.createModuleEntryPoint ./.;
in
modules
// {
  # NixOS hosts also get the shared system modules (../common).
  default = {
    imports = [
      modules.default
      self.modules.common.default
    ];
  };
}
