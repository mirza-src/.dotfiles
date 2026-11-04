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
        go
        jq
        yq-go
        teleport
        github-cli

        tilt
        kind

        nancy
        renovate
        vendir
        kube-linter
        pre-commit
        helm-docs
        # kubernetes-helm
        (pkgs.wrapHelm pkgs.kubernetes-helm { plugins = with kubernetes-helmPlugins; [ helm-schema ]; })

        _1password-cli
        (_1password-gui.override {
          polkitPolicyOwners = [ config.home.username ];
        })
        devctl
      ]
      ++ (with giantswarm; [
        gg
        kubectl-gs
        luigi
        opsctl
        gsctl
        nancy-fixer
        architect

        helm-values-gen
        schemalint
        schemadocs
      ])
    );

    programs.ssh-agent-switch.agents."1password" = "${config.home.homeDirectory}/.1password/agent.sock";
  };
}
