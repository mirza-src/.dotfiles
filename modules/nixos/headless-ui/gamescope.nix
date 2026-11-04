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

  cfg = config.services.gamescope-headless;

  gamescopeScript = pkgs.writeShellScript "gamescope-headless-run" ''
    set -euo pipefail

    # Launch Gamescope via prime-run / NVIDIA offload with an idle sleep process
    ${pkgs.gamescope}/bin/gamescope \
      -W ${toString cfg.width} \
      -H ${toString cfg.height} \
      -r ${toString cfg.refresh} \
      -s ${toString cfg.scale} \
      --headless \
      --wayland-display ${cfg.wayland-display} \
      --cursor-hotspot 0,0 \
      -- ${pkgs.coreutils}/bin/sleep infinity
  '';
in
{
  options.services.gamescope-headless = {
    enable = mkEnableOption "Enable a headless Gamescope compositor running idle for Sunshine streaming.";

    autoStart = mkOption {
      default = true;
      description = "Automatically start the headless Gamescope compositor on graphical session startup.";
      type = types.bool;
    };

    width = mkOption {
      default = 1920;
      description = "Virtual display width for the headless Gamescope session.";
      type = types.int;
    };

    height = mkOption {
      default = 1080;
      description = "Virtual display height for the headless Gamescope session.";
      type = types.int;
    };

    refresh = mkOption {
      default = 60;
      description = "Virtual display refresh rate in Hz.";
      type = types.int;
    };

    scale = mkOption {
      default = 1;
      description = "Internal scaling factor for Gamescope.";
      type = types.int;
    };

    wayland-display = mkOption {
      default = "gamescope-0";
      description = "The WAYLAND_DISPLAY socket exposed by Gamescope.";
      type = types.str;
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      gamescope
    ];

    systemd.user.services.gamescope-headless = {
      description = "Headless Gamescope Session (Idle Host)";

      wantedBy = mkIf cfg.autoStart [ "graphical-session.target" ];
      partOf = [ "graphical-session.target" ];
      after = [ "graphical-session.target" ];

      environment = {
        XDG_SESSION_TYPE = "wayland";
        XDG_CURRENT_DESKTOP = "gamescope";

        # Enforce NVIDIA Vulkan stack
        GBM_BACKEND = "nvidia-drm";
        # __GLX_VENDOR_LIBRARY_NAME = "nvidia";
        # VK_DRIVER_FILES = "/run/opengl-driver/share/vulkan/icd.d/nvidia_icd.x86_64.json";

        # Fix cursor bugs in headless screencopy
        WLR_NO_HARDWARE_CURSORS = "1";

        __NV_PRIME_RENDER_OFFLOAD = "1";
        __NV_PRIME_RENDER_OFFLOAD_PROVIDER = "NVIDIA-G0";
        __GLX_VENDOR_LIBRARY_NAME = "nvidia";
        __VK_LAYER_NV_optimus = "NVIDIA_only";
      };

      serviceConfig = {
        ExecStart = "${gamescopeScript}";
        Restart = "on-failure";
        RestartSec = "2s";
      };
    };
  };
}
