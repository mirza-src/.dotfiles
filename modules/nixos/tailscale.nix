# NixOS half of modules.tailscale (declared in ../common/tailscale.nix).
{ lib, config, ... }:
{
  config = lib.mkIf config.modules.tailscale.enable {
    # Open tailscaled's UDP port, so peers connect directly instead of
    # through a DERP relay.
    services.tailscale.openFirewall = true;
  };
}
