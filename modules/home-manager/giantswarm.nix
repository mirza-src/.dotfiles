{
  lib,
  pkgs,
  config,
  inputs,
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
    nixpkgs.overlays = [ inputs.giantswarm.overlay ];

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

        # From nix-gs (inputs.giantswarm.overlay)
        architect
        devctl
        kubectl-gs
        opsctl
      ]
      ++ (with giantswarm; [
        helm-values-gen
        luigi
        nancy-fixer
        schemadocs
        schemalint
      ])
    );

    programs.ssh-agent-switch.agents."1password" = "${config.home.homeDirectory}/.1password/agent.sock";
  };
}
