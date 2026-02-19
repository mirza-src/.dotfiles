{
  pkgs,
  lib,
  config,
  ...
}:
with lib;
let
  cfg = config.modules.audio;
in
{
  options.modules.audio = {
    enable = mkEnableOption "Enable sane audio configuration";
  };

  config = mkIf cfg.enable {
    # Enable sound with pipewire.
    services.pulseaudio.enable = false;
    services.pulseaudio.package = pkgs.pulseaudioFull;
    security.rtkit.enable = true;
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      # If you want to use JACK applications, uncomment this
      #jack.enable = true;

      # use the example session manager (no others are packaged yet so this is enabled by default,
      # no need to redefine it in your config for now)
      #media-session.enable = true;
    };

    environment.systemPackages = with pkgs; [
      easyeffects
    ];

    # Allow volume above 100% in GNOME.
    programs.dconf = mkIf config.services.desktopManager.gnome.enable {
      enable = true;
      profiles.user.databases = [
        {
          settings = {
            "org/gnome/desktop/sound" = {
              allow-volume-above-100-percent = true;
            };
          };
        }
      ];
    };
  };
}
