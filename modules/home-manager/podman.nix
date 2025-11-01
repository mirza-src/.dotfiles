{
  lib,
  pkgs,
  config,
  ...
}:
with lib;
let
  cfg = config.modules.podman;
in
{
  options.modules.podman = {
    enable = mkEnableOption "Enable Podman for container management";

    tui = mkEnableOption "Enable Podman TUI" // {
      default = true;
    };

    desktop = mkEnableOption "Enable Podman Desktop application";

    dockerAlias =
      mkEnableOption "Alias docker and docker-compose commands to podman and podman-compose respectively"
      // {
        default = false;
      };
  };

  config = mkIf cfg.enable {
    services.podman.enable = true;

    home.packages =
      with pkgs;
      [
        podman-compose
      ]
      ++ (if cfg.tui then [ podman-tui ] else [ ])
      ++ (if cfg.desktop then [ podman-desktop ] else [ ]);

    home.shellAliases = mkIf cfg.dockerAlias {
      docker = "podman";
      docker-compose = "podman-compose";
    };
  };
}
