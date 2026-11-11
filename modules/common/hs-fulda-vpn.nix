# Hochschule Fulda eduVPN as a WireGuard (wg-quick) interface, on NixOS and
# macOS (same networking.wg-quick options). Not started automatically:
#   NixOS: sudo systemctl start wg-quick-hs-fulda
#   macOS: sudo wg-quick up hs-fulda
# Each device has its own eduVPN profile, hence its own address and key.
{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.modules.hs-fulda-vpn;
  home = "${
    if pkgs.stdenv.hostPlatform.isDarwin then "/Users" else "/home"
  }/${config.modules.defaults.primaryUser}";
in
{
  options.modules.hs-fulda-vpn = {
    enable = lib.mkEnableOption "the Hochschule Fulda WireGuard VPN (hs-fulda)";

    address = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      example = [
        "10.248.0.9/19"
        "2001:638:301:f820::9/64"
      ];
      description = "This device's addresses from its eduVPN WireGuard profile.";
    };

    privateKeyFile = lib.mkOption {
      type = lib.types.str;
      default = "${home}/.wg/hs-fulda.key";
      defaultText = lib.literalExpression ''"<home of primaryUser>/.wg/hs-fulda.key"'';
      description = "Private key from this device's eduVPN WireGuard profile.";
    };

    mtu = lib.mkOption {
      type = lib.types.nullOr lib.types.int;
      default = null;
      description = "Interface MTU; null for wg-quick's default.";
    };
  };

  config = lib.mkIf cfg.enable {
    networking.wg-quick.interfaces.hs-fulda = {
      autostart = false;
      inherit (cfg) address privateKeyFile mtu;
      dns = [
        "10.0.0.53"
        "2001:638:301::53"
      ];
      peers = [
        {
          endpoint = "eduvpn01.rz.hs-fulda.de:443";
          publicKey = "E9rVjRfxl5F6amOjc5FBQ7+1minLp60LetMF/y2N3wE=";
          allowedIPs = [
            "0.0.0.0/0"
            "::/0"
          ];
        }
      ];
    };
  };
}
