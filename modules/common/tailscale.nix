# Tailscale on NixOS and macOS (same services.tailscale option). Joins this
# machine to the tailnet, so its services (modules.reverse-proxy) are
# reachable from the other machines, on the LAN and remotely, by their
# MagicDNS names (zephyrus, macbook-pro).
#
# tailscaled starts at boot on both (systemd / launchd) and reconnects by
# itself. Only the very first time, to log the machine in once:
#   sudo tailscale up
{ lib, config, ... }:
{
  options.modules.tailscale = {
    enable = lib.mkEnableOption "Tailscale";

    domain = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "tail1234.ts.net";
      description = ''
        The tailnet's DNS name (admin console > DNS, or
        `tailscale status --json | jq -r .MagicDNSSuffix`). With it, the
        reverse proxy serves https://<host>.<domain> with a certificate from
        Tailscale (enable "HTTPS Certificates" on that page first).
      '';
    };
  };

  config = lib.mkIf config.modules.tailscale.enable {
    services.tailscale.enable = true;
  };
}
