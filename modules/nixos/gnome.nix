{
  lib,
  pkgs,
  config,
  ...
}:
with lib;
let
  cfg = config.modules.gnome;
in
{
  options.modules.gnome = {
    enable = mkEnableOption "Enable GNOME Desktop Environment";
    extensions = mkOption {
      default = with pkgs.gnomeExtensions; [
        appindicator
        battery-health-charging
      ];
      type = types.listOf types.package;
      description = "List of GNOME Shell extensions to enable.";
      example = lib.literalExpression "[ pkgs.gnomeExtensions.appindicator ]";
    };
  };

  config = mkIf cfg.enable {
    services.desktopManager.gnome.enable = true;

    environment.systemPackages =
      with pkgs;
      [
        dconf-editor
        gthumb
        gnome-tweaks
        yaru-theme
      ]
      ++ cfg.extensions;
    programs.dconf = {
      enable = true;
      profiles.user.databases = [
        {
          lockAll = false; # prevents overriding
          settings = {
            "org/gnome/desktop/datetime" = {
              automatic-timezone = true;
            };
            "org/gnome/system/location" = {
              enabled = true;
            };
            "org/gnome/desktop/interface" = {
              color-scheme = "prefer-dark";
              cursor-theme = "Yaru";
              gtk-theme = "Yaru";
              icon-theme = "Yaru";
              show-battery-percentage = true;
            };
            "org/gnome/shell" = {
              disable-user-extensions = false; # enables user extensions
              enabled-extensions = builtins.map (ext: ext.extensionUuid) cfg.extensions;
            };
          };
        }
      ];
    };
  };
}
