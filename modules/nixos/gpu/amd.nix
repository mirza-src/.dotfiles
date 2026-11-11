{
  pkgs,
  lib,
  config,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkIf
    ;
  cfg = config.modules.gpu.amd;
in
{
  imports = [
    ./gpu.nix
  ];

  options.modules.gpu.amd = {
    enable = mkEnableOption "Enable AMD GPU Options";
  };

  config = mkIf cfg.enable {
    modules.gpu.enable = true;
    boot.initrd.kernelModules = [ "amdgpu" ];
    # services.xserver.videoDrivers = [ "amdgpu" ];
  };
}
