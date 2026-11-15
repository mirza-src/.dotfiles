# macOS half of modules.reverse-proxy (../common/reverse-proxy.nix): Caddy as
# a launchd daemon (root, for ports 80/443 and tailscaled's certificates).
# Logs: /var/log/caddy.log.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.modules.reverse-proxy;
in
{
  config = lib.mkIf cfg.enable {
    launchd.daemons.caddy.serviceConfig = {
      ProgramArguments = [
        (lib.getExe pkgs.caddy)
        "run"
        "--adapter=caddyfile"
        "--config=${builtins.toFile "Caddyfile" cfg.caddyfile}"
      ];
      EnvironmentVariables = {
        XDG_DATA_HOME = "/var/db"; # certificates in /var/db/caddy
        XDG_CONFIG_HOME = "/var/db";
      };
      RunAtLoad = true;
      KeepAlive = true;
      StandardOutPath = "/var/log/caddy.log";
      StandardErrorPath = "/var/log/caddy.log";
    };
  };
}
