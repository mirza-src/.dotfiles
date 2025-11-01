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

    networkmanager = {
      enable = mkEnableOption "Enable NetworkManager Integration";
    };
  };

  config = mkIf cfg.enable {
    home.packages =
      with pkgs;
      [
        eduvpn-client
        protonvpn-gui
        openconnect
        wireguard-tools
      ]
      ++ (lib.optionals (cfg.networkmanager.enable) [
        networkmanager-openconnect
      ]);
  };
}
