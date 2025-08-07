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
      egl-wayland
      wofi
      kdePackages.dolphin
      waybar
      brightnessctl
      playerctl
      hyprpaper
      networkmanagerapplet

      libnotify
      swaynotificationcenter
      hyprshot
      hypridle
      hyprlock
    ];
  };
}
