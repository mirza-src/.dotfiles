{
  lib,
  pkgs,
  config,
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
    ];
  };
}
