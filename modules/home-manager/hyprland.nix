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
    };
    services.gnome-keyring.enable = true;
    services.polkit-gnome.enable = true;

    home.sessionVariables = {
      HYPRSHOT_DIR = "${options.home.homeDirectory}/Pictures/Screenshots";
    };

    home.packages = with pkgs; [
      kitty
      kdePackages.dolphin
      kdePackages.ark
      egl-wayland
      libnotify

      hyprshot
      hypridle
      hyprlock
      material-symbols
      quickshell-with-modules

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
      pipewire
      glibc
      gcc
      grim
      swappy
    ];
  };
}
