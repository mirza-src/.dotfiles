{
  lib,
  pkgs,
  config,
  options,
  ...
}:
with lib;
let
  cfg = config.modules.hyprland;
in
{
  options.modules.hyprland = {
    enable = mkEnableOption "Enable Hyprland desktop environment";
  };

  config = mkIf cfg.enable {
    wayland.windowManager.hyprland = {
      enable = true;
      systemd.enable = false;
    };
    services.gnome-keyring.enable = true;

    home.sessionVariables = {
      HYPRSHOT_DIR = "${options.home.homeDirectory}/Pictures/Screenshots";
    };

    home.packages = with pkgs; [
      gcr # https://github.com/nix-community/home-manager/issues/1454#issuecomment-2781057551
      kitty
      ghostty
      kdePackages.dolphin
      kdePackages.ark
      egl-wayland
      libnotify

      hyprshot
      hypridle
      hyprlock
      material-symbols

      cava
      libqalculate
      cliphist
      ddcutil
      translate-shell
      brightnessctl
      playerctl

      app2unit
      lm_sensors
      fish
      aubio
      glibc
      gcc
      grim
      swappy
    ];
  };
}
