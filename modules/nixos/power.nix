{
  lib,
  pkgs,
  config,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkIf
    ;
  cfg = config.modules.power;
in
{
  options.modules.power = {
    enable = mkEnableOption "power management optimizations and tools";
  };

  config = mkIf cfg.enable {
    powerManagement.enable = true;
    powerManagement.powertop.enable = true;
    systemd.services.powertop.serviceConfig.ExecStart = "${pkgs.powertop}/bin/powertop --auto-tune";

    services.upower.enable = true;
    services.thermald.enable = false;

    services.tlp = {
      enable = true;
      pd.enable = true;
      settings = {
        CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
        CPU_BOOST_ON_BAT = 0;
        SCHED_POWERSAVE_ON_BAT = 1;

        # Aggressive PCIe and SATA link power management
        RUNTIME_PM_ON_BAT = "auto";
        PCIE_ASPM_ON_BAT = "powersave";

        # Disable wake-on-lan
        WOL_DISABLE = "Y";

        # MT7925 power save drops/delays UDP heavily (Cast mirroring stalls
        # with thousands of resent packets); keep it off on battery too.
        WIFI_PWR_ON_BAT = "off";
      };
    };

    services.auto-cpufreq = {
      enable = false;
      settings = {
        battery = {
          governor = "powersave";
          turbo = "never"; # Aggressively prevents CPU from boosting on battery
        };
        charger = {
          governor = "performance";
          turbo = "auto";
        };
      };
    };

    environment.systemPackages = with pkgs; [
      powertop
    ];
  };
}
