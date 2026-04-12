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

  cfg = config.services.sway-headless;

  headlessConfig = pkgs.writeText "sway-headless-config" ''
    # Performance tuning
    output * allow_tearing yes
    output * max_render_time off

    # Create virtual monitor
    output HEADLESS-1 mode ${cfg.mode}

    # Isolate session: disable all physical input devices
    input "*" events disabled
  '';
in
{
  options.services.sway-headless = {
    enable = mkEnableOption "Enable a headless Sway compositor for Sunshine.";

    autoStart = mkEnableOption "Automatically start the headless Sway compositor";

    mode = mkOption {
      default = "1920x1080@60Hz";
      description = "The virtual display mode for the headless Sway compositor.";
      type = types.str;
    };

    socket = mkOption {
      default = "sway-headless.sock";
      description = "The path to the Wayland socket for the headless Sway compositor.";
      type = types.str;
    };

    wlr-renderer = mkOption {
      default = "gles2";
      description = "The WLR_RENDERER to use for the headless Sway compositor.";
      type = types.str;
    };

    wayland-display = mkOption {
      default = "wayland-2";
      description = "The WAYLAND_DISPLAY socket name for the headless Sway compositor.";
      type = types.str;
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      sway
    ];

    # Create the systemd service for the Headless Sway compositor
    systemd.user.services.sway-headless = {
      description = "Headless Sway Compositor";

      wantedBy = mkIf cfg.autoStart [ "graphical-session-pre.target" ];
      partOf = [ "graphical-session-pre.target" ];
      wants = [ "graphical-session-pre.target" ];
      after = [ "graphical-session-pre.target" ];

      environment = {
        WLR_BACKENDS = "headless";
        LIBSEAT_BACKEND = "noop";
        WLR_LIBINPUT_NO_DEVICES = "1";
        XDG_SESSION_TYPE = "wayland";
        XDG_CURRENT_DESKTOP = "sway";
        WLR_RENDERER = cfg.wlr-renderer;
        WAYLAND_DISPLAY = cfg.wayland-display;
        SWAYSOCK = "%t/${cfg.socket}";
        PATH = lib.mkForce null; # Clear PATH to allow access to EVERYTHING
      };

      serviceConfig = {
        ExecStartPre = "${pkgs.coreutils}/bin/rm -f ${cfg.socket}"; # Ensure old socket is removed
        ExecStart = "${pkgs.sway}/bin/sway -c ${headlessConfig}";
        Restart = "on-failure";
      };
    };
  };
}
