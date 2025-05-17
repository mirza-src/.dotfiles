{ pkgs, ... }: {
  # Enable the GNOME Desktop Environment.
  services.xserver.displayManager.gdm.enable = true;
  services.xserver.desktopManager.gnome.enable = true;
  programs.dconf = {
    enable = true;
    profiles.user.databases = [
      {
        lockAll = true; # prevents overriding
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
          "org/gnome/desktop/sound" = {
            allow-volume-above-100-percent = true;
          };
          "org/gnome/shell" = {
            disable-user-extensions = false; # enables user extensions
            enabled-extensions = with pkgs.gnomeExtensions; [
              appindicator.extensionUuid
              battery-health-charging.extensionUuid

              freon.extensionUuid
              settingscenter.extensionUuid
              zen.extensionUuid
              containers.extensionUuid
            ];
          };
        };
      }
    ];
  };
}