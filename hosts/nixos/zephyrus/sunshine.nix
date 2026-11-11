# Sunshine game streaming (started on demand). With services.mango-headless
# enabled it streams a headless mango session that lives as long as Sunshine;
# otherwise it captures the regular desktop.
{
  pkgs,
  lib,
  config,
  ...
}:
let
  headless = config.services.mango-headless;
in
{
  # services.mango-headless.enable = true;
  # services.mango-headless.wlr-render-device = "/dev/dri/renderD129"; # AMD GPU render node

  services.sunshine = {
    enable = true;
    autoStart = false;
    capSysAdmin = true;
    openFirewall = true;
    settings = {
      adapter_name = "/dev/dri/renderD129";
      encoder = "vaapi";
    };
    applications = {
      apps = [
        {
          name = "Steam";
          detached = [
            "${pkgs.util-linux}/bin/setsid ${pkgs.steam}/bin/steam steam://open/bigpicture"
          ];
          prep-cmd = [
            # {
            #   do = "mmsg dispatch create_virtual_output,HEADLESS-1";
            #   undo = "mmsg dispatch destroy_virtual_output,HEADLESS-1";
            # }
            # {
            #   do = "wlr-randr --output HEADLESS-1 --custom-mode \${SUNSHINE_CLIENT_WIDTH}x\${SUNSHINE_CLIENT_HEIGHT}@\${SUNSHINE_CLIENT_FPS}Hz";
            # }
          ];
        }
      ];
    };
  };

  # Only when the headless compositor exists: setting these on a disabled
  # mango-headless created a unit without ExecStart that Sunshine required.
  systemd.user.services = lib.mkIf headless.enable {
    mango-headless = {
      bindsTo = [ "sunshine.service" ];
      before = [ "sunshine.service" ];
    };
    sunshine = {
      requires = [ "mango-headless.service" ];
      after = [ "mango-headless.service" ];
      environment = {
        WAYLAND_DISPLAY = headless.wayland-display;
        MANGO_INSTANCE_SIGNATURE = headless.socket;
        XDG_SESSION_TYPE = "wayland";
        XDG_CURRENT_DESKTOP = "mango";
      };
    };
  };
}
