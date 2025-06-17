{
  lib,
  pkgs,
  config,
  ...
}:
with lib;
let
  cfg = config.modules.vpn;
in
{
  options.modules.vpn = {
    enable = mkEnableOption "Enable VPN tools";
  };

  config = mkIf cfg.enable {
    home.packages =
      with pkgs;
      [
        eduvpn-client
        protonvpn-gui
        openconnect
      ]
      ++ (lib.optionals (config.networking.networkmanager.enable) [
        networkmanager-openconnect
      ]);
  };
}
