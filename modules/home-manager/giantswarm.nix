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
        (devctl.overrideAttrs (finalAttrs: {
          version = "8.163.0";
          src = pkgs.fetchFromGitHub {
            owner = "giantswarm";
            repo = finalAttrs.pname;
            rev = "v${finalAttrs.version}";
            hash = "sha256-52L1M+bQ8d93dpmafTCLDYOQ+JeOMjnHoB9aKYJGu08=";
          };
        }))
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
