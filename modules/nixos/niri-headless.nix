{
  pkgs,
  config,
  lib,
  ...
}:

let
  inherit (lib)
    mkEnableOption
    mkOption
    mkIf
    types
    ;

  cfg = config.services.niri-headless;

  niri-config = pkgs.writeText "niri-headless-config" (
    (lib.optionalString cfg.wayvnc.enable ''
      spawn-at-startup "${pkgs.wayvnc}/bin/wayvnc" "0.0.0.0" "${toString cfg.wayvnc.port}"

    '')
    + (lib.optionalString cfg.include-home-config ''
      include "/home/mirza/.config/niri/config.kdl"

    '')
  );
in
{
  options.services.niri-headless = {
    enable = mkEnableOption "Enable a headless Niri compositor.";

    autoStart = mkEnableOption "Automatically start the headless Niri compositor";

    width = mkOption {
      default = 1920;
      description = "The width of the virtual display for the headless Niri compositor.";
      type = types.int;
    };

    height = mkOption {
      default = 1080;
      description = "The height of the virtual display for the headless Niri compositor.";
      type = types.int;
    };

    refresh-rate = mkOption {
      default = 60;
      description = "The refresh rate of the virtual display for the headless Niri compositor.";
      type = types.int;
    };

    socket = mkOption {
      default = "niri-headless.sock";
      description = "The path to the socket for the headless Niri compositor.";
      type = types.str;
    };

    wayland-display = mkOption {
      default = "wayland-9";
      description = "The WAYLAND_DISPLAY socket name for the headless Niri compositor.";
      type = types.str;
    };

    include-home-config =
      (mkEnableOption "Whether to include the user's home config in the headless Niri compositor.")
      // {
        default = true;
      };

    wayvnc = {
      enable = (mkEnableOption "Enable the wayvnc VNC server for the headless Niri compositor.") // {
        default = true;
      };

      port = mkOption {
        default = 5900;
        description = "The port on which the wayvnc VNC server will listen.";
        type = types.int;
      };
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      niri
      dms
      kitty
      wayvnc
      wlvncc
    ];

    # Create the systemd service for the Headless Niri compositor
    systemd.user.services.niri-headless = {
      description = "Headless Niri Compositor";

      wantedBy = mkIf cfg.autoStart [ "graphical-session-pre.target" ];
      partOf = [ "graphical-session-pre.target" ];
      wants = [ "graphical-session-pre.target" ];
      after = [ "graphical-session-pre.target" ];

      environment = {
        NIRI_BACKEND = "headless";
        NIRI_CONFIG = niri-config;
        XDG_SEAT = "noop";
        XDG_SESSION_TYPE = "wayland";
        XDG_CURRENT_DESKTOP = "niri";
        # WAYLAND_DISPLAY = cfg.wayland-display;
        NIRI_SOCKET = "%t/${cfg.socket}";
        PATH = lib.mkForce null; # Clear PATH to allow access to EVERYTHING
      };

      serviceConfig = {
        ExecStartPre = "${pkgs.coreutils}/bin/rm -f ${cfg.socket}"; # Ensure old socket is removed
        ExecStart = "${pkgs.niri}/bin/niri --session";
        Restart = "on-failure";
      };
    };
  };
}
