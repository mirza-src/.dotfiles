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
    dockerAlias = mkOption {
      type = types.bool;
      default = true;
      description = "Create an alias for 'docker' to 'podman'";
    };
  };

  config = mkIf cfg.enable {
    services.podman.enable = true;

    home.packages = with pkgs; [
      podman-compose
      podman-tui
      podman-desktop
    ];

    home.shellAliases = mkIf cfg.dockerAlias {
      docker = "podman";
      docker-compose = "podman-compose";
    };
  };
}
