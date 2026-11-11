# 1Password app and CLI, from the system on both platforms: macOS only runs the
# app from /Applications (nix-darwin copies it there), and on NixOS the system
# module wires up polkit (system authentication) and CLI integration. The SSH
# agent socket is registered per user in the giantswarm home-manager module.
{ lib, config, ... }:
let
  cfg = config.modules.onepassword;
in
{
  options.modules.onepassword.enable = lib.mkEnableOption "the 1Password app and CLI";

  config = lib.mkIf cfg.enable {
    programs._1password.enable = true;
    programs._1password-gui.enable = true;
  };
}
