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

  cfg = config.services.mango-headless;

  headlessConfig = pkgs.writeText "mango-headless-config" ''
    # Performance tuning
    allow_tearing=1

    monitorrule=name:*,width:${toString cfg.width},height:${toString cfg.height},refresh:${toString cfg.refresh},x:0,y:0,scale:${toString cfg.scale}
  '';
in
{
  options.services.mango-headless = {
    enable = mkEnableOption "Enable a headless Mango compositor for Sunshine.";

    autoStart = mkEnableOption "Automatically start the headless Mango compositor";

    width = mkOption {
      default = 1920;
      description = "The virtual display width for the headless Mango compositor.";
      type = types.int;
    };

    height = mkOption {
      default = 1080;
      description = "The virtual display height for the headless Mango compositor.";
      type = types.int;
    };

    refresh = mkOption {
      default = 60;
      description = "The virtual display refresh rate for the headless Mango compositor.";
      type = types.int;
    };

    scale = mkOption {
      default = 1.0;
      description = "The virtual display scale factor for the headless Mango compositor.";
      type = types.float;
    };

    socket = mkOption {
      default = "mango-headless.sock";
      description = "The path to the Wayland socket for the headless Mango compositor.";
      type = types.str;
    };

    wlr-renderer = mkOption {
      default = "vulkan";
      description = "The WLR_RENDERER to use for the headless Mango compositor.";
      type = types.str;
    };

    wlr-render-device = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      example = "/dev/dri/renderD129";
      description = "DRI render node to use for wlroots.";
    };

    wayland-display = mkOption {
      default = "wayland-9";
      description = "The WAYLAND_DISPLAY socket name for the headless Mango compositor.";
      type = types.str;
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      mango
    ];

    # Create the systemd service for the Headless Mango compositor
    systemd.user.services.mango-headless = {
      description = "Headless Mango Compositor";

      wantedBy = mkIf cfg.autoStart [ "graphical-session-pre.target" ];
      partOf = [ "graphical-session-pre.target" ];
      wants = [ "graphical-session-pre.target" ];
      after = [ "graphical-session-pre.target" ];

      environment = {
        WLR_BACKENDS = "headless";
        LIBSEAT_BACKEND = "noop";
        WLR_LIBINPUT_NO_DEVICES = "1";
        XDG_SESSION_TYPE = "wayland";
        XDG_CURRENT_DESKTOP = "mango";
        WLR_RENDERER = cfg.wlr-renderer;
        WAYLAND_DISPLAY = cfg.wayland-display;
        MANGO_INSTANCE_SIGNATURE = "%t/${cfg.socket}";
        PATH = lib.mkForce null; # Clear PATH to allow access to EVERYTHING
        WLR_RENDER_DRM_DEVICE = cfg.wlr-render-device;
      };

      serviceConfig = {
        ExecStartPre = "${pkgs.coreutils}/bin/rm -f %t/${cfg.socket}"; # Ensure old socket is removed
        ExecStart = "${pkgs.mango}/bin/mango -c ${headlessConfig}";
        Restart = "on-failure";
      };
    };
  };
}
