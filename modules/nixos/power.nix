{
  lib,
  pkgs,
  config,
  ...
}:
with lib;
let
  cfg = config.modules.power;
in
{
  options.modules.power = {
    enable = mkEnableOption "Enable power management optimizations and tools";
  };

  config = mkIf cfg.enable {
    powerManagement.enable = true;
    powerManagement.cpuFreqGovernor = "powersave";
    powerManagement.powertop.enable = true;

    services.thermald.enable = true;
    services.power-profiles-daemon.enable = true;

    environment.systemPackages = with pkgs; [
      powertop
    ];
  };
}
