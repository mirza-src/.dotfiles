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
  cfg = config.modules.giantswarm;
in
{
  options.modules.giantswarm = {
    enable = mkEnableOption "GiantSwarm tools";
  };

  config = mkIf cfg.enable {
    home.packages =
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

        _1password-cli
        (_1password-gui.override {
          polkitPolicyOwners = [ config.home.username ];
        })

        # From nix-gs (its overlay is applied in flake.nix)
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
      ]);

    # helm itself comes from the kubernetes module, wrapped with this plugin.
    modules.kubernetes.enable = true;
    modules.kubernetes.helmPlugins = [ pkgs.kubernetes-helmPlugins.helm-schema ];

    programs.ssh-agent-switch.agents."1password" = "${config.home.homeDirectory}/.1password/agent.sock";
  };
}
