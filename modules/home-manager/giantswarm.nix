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
        cert-manager.helm-tool
        nancy
        go
        tilt
        kind
        clusterctl
        fluxcd

        (_1password-gui.override {
          polkitPolicyOwners = [ config.home.username ];
        })
        _1password-cli
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

    programs.ssh-agent-switch.agents."1password" = "${config.home.homeDirectory}/.1password/agent.sock";
  };
}
