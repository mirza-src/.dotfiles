{ lib, config, ... }:
with lib;
let
  cfg = config.modules.silent-boot;
in
{
  options.modules.silent-boot = {
    enable = mkEnableOption "Enable Silent Booting";
  };

  config = mkIf cfg.enable {
    boot.plymouth.enable = true;
    boot.initrd.verbose = false;
    boot.loader.timeout = 0;
    boot.consoleLogLevel = 0;
    boot.loader.systemd-boot.consoleMode = "2";
    boot.kernelParams = [
      "quiet"
      "splash"
      "rd.systemd.show_status=false"
      "rd.udev.log_level=3"
      "udev.log_priority=3"
      "boot.shell_on_fail"
    ];
  };
}
