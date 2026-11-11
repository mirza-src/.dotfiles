# nix-darwin half of the host defaults; the shared half (nix settings,
# overlays, hostname, nh) is ../common/defaults.nix, which declares
# `modules.defaults`.
{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.modules.defaults;
in
{
  config = lib.mkIf cfg.enable {
    system.primaryUser = cfg.primaryUser;

    # Display name in AirDrop, Finder sharing and Bluetooth; the hostname
    # (and Bonjour name, <hostname>.local) stays lowercase.
    networking.computerName = cfg.displayName;

    # Lix instead of CppNix, managed by nix-darwin (daemon and nix.conf).
    nix.package = pkgs.lix;

    # GitHub token for fetchFromGitHub { private = true; } sources (opsctl
    # from nix-gs), same file as on NixOS (see ../nixos/defaults.nix):
    # launchd can't read an environment file, so the daemon starts through a
    # wrapper that loads it when present.
    launchd.daemons.nix-daemon.command = lib.mkForce (
      toString (
        pkgs.writeShellScript "nix-daemon-with-env" ''
          if [ -r /etc/nix/github-private.env ]; then
            set -a
            . /etc/nix/github-private.env
            set +a
          fi
          exec ${lib.getExe' config.nix.package "nix-daemon"}
        ''
      )
    );

    # Touch ID for sudo, also inside tmux.
    security.pam.services.sudo_local = {
      touchIdAuth = true;
      reattach = true;
    };

    system.defaults = {
      NSGlobalDomain = {
        AppleShowAllExtensions = true;
        ApplePressAndHoldEnabled = false; # key repeat instead of the accent menu
      };
      dock = {
        autohide = true;
        show-recents = false;
        launchanim = false;
        tilesize = 64;
      };
      trackpad = {
        Clicking = true; # tap to click
        TrackpadThreeFingerDrag = true;
      };
    };
  };
}
