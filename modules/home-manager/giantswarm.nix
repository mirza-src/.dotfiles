{
  lib,
  pkgs,
  config,
  ...
}:
with lib;
let
  cfg = config.modules.giantswarm;
in
{
  options.modules.giantswarm = {
    enable = mkEnableOption "Enable GiantSwarm tools";
  };

  config = mkIf cfg.enable {
    home.packages = (
      with pkgs;
      [
        gojq
        teleport
        helm-schema-gen
        certManager.helm-tool
        nancy
        go
      ]
      ++ (with giantswarm; [
        devctl
        gg
        kubectl-gs
        luigi
        opsctl
        gsctl
        nancy-fixer
      ])
    );
  };
}
