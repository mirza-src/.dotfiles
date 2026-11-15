# NixOS half of modules.reverse-proxy (../common/reverse-proxy.nix).
{ config, lib, ... }:
let
  cfg = config.modules.reverse-proxy;
  ports = [
    80
    443
  ];
in
{
  config = lib.mkIf cfg.enable {
    services.caddy = {
      enable = true;
      configFile = builtins.toFile "Caddyfile" cfg.caddyfile;
    };

    # Lets Caddy fetch the *.ts.net certificate from tailscaled.
    services.tailscale.permitCertUid = lib.mkIf config.modules.tailscale.enable "caddy";

    networking.firewall =
      if cfg.lanAccess then
        { allowedTCPPorts = ports; }
      else
        { interfaces.tailscale0.allowedTCPPorts = ports; };
  };
}
