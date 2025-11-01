{
  pkgs,
  lib,
  config,
  ...
}:
with lib;
let
  cfg = config.modules.bluetooth;
in
{
  options.modules.bluetooth = {
    enable = mkEnableOption "Enable sane bluetooth configuration";
  };

  config = mkIf cfg.enable {
    hardware.bluetooth.enable = true;
    hardware.bluetooth.settings = {
      General = {
        Enable = "Source,Sink,Media,Socket"; # Enabling A2DP Sink
        Experimental = true; # Showing battery charge of bluetooth devices
      };
    };

    # Automatically switch audio to the connected bluetooth device when it connect
    services.pulseaudio.extraConfig = "
      load-module module-switch-on-connect
    ";

    # Using Bluetooth headset buttons to control media player
    systemd.user.services.mpris-proxy = {
      description = "Mpris proxy";
      after = [
        "network.target"
        "sound.target"
      ];
      wantedBy = [ "default.target" ];
      serviceConfig.ExecStart = "${pkgs.bluez}/bin/mpris-proxy";
    };
  };
}
