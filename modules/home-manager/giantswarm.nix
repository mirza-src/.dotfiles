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

  # tsh loads its certs into $SSH_AUTH_SOCK by default, and the Bitwarden
  # agent refuses ssh-add ("agent: failure"), which fails every tsh command.
  # tsh reads the certs from ~/.tsh itself, so it doesn't need the agent.
  # Set in a wrapper (not sessionVariables) so it applies without re-login;
  # --set-default keeps a per-command override possible.
  teleport' = pkgs.symlinkJoin {
    name = "teleport-${pkgs.teleport.version}";
    paths = [ pkgs.teleport ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/tsh --set-default TELEPORT_ADD_KEYS_TO_AGENT no
    '';
    inherit (pkgs.teleport) meta;
  };
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
        teleport'
        github-cli

        tilt
        kind

        nancy
        renovate
        vendir
        kube-linter
        pre-commit
        helm-docs

        # 1Password itself comes from the host (modules.onepassword).

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

    programs.profile-switch.switches.ssh.options."1password" =
      if pkgs.stdenv.hostPlatform.isDarwin then
        "${config.home.homeDirectory}/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
      else
        "${config.home.homeDirectory}/.1password/agent.sock";
  };
}
