{
  lib,
  pkgs,
  config,
  ...
}:
with lib;
let
  cfg = config.modules.gpu;
in
{
  options.modules.gpu = {
    enable = mkEnableOption "Enable general GPU tools and settings";
  };

  config = mkIf cfg.enable {
    services.lact.enable = true;
    environment.systemPackages = with pkgs; [
      nvtopPackages.full
    ];
    hardware.graphics = {
      enable = true;
      enable32Bit = true;
    };
  };
}
