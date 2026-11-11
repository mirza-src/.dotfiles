{
  lib,
  pkgs,
  config,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkIf
    ;
  cfg = config.modules.podman;
in
{
  options.modules.podman = {
    enable = mkEnableOption "Podman for container management";

    tui = mkEnableOption "Podman TUI" // {
      default = true;
    };

    desktop = mkEnableOption "Podman Desktop application";

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
