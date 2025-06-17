{
  pkgs,
  lib,
  config,
  ...
}:
with lib;
let
  cfg = config.modules.gpu-amd;
in
{
  imports = [
    # ./gpu.nix
  ];

  options.modules.gpu-amd = {
    enable = mkEnableOption "Enable AMD GPU Options";
  };

  config = mkIf cfg.enable {
    boot.initrd.kernelModules = [ "amdgpu" ];
    # services.xserver.videoDrivers = [ "amdgpu" ];

    hardware.amdgpu.amdvlk = {
      enable = true;
      support32Bit.enable = true;
    };
  };
}
