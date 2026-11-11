{
  lib,
  pkgs,
  config,
  ...
}:
let
  inherit (lib)
    literalExpression
    mkEnableOption
    mkIf
    mkOption
    types
    ;
  cfg = config.modules.kubernetes;
in
{
  options.modules.kubernetes = {
    enable = mkEnableOption "Kubernetes tools";

    helmPlugins = mkOption {
      type = types.listOf types.package;
      default = [ ];
      example = literalExpression "[ pkgs.kubernetes-helmPlugins.helm-diff ]";
      description = "Helm plugins to wrap the helm binary with.";
    };
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      kubectl
      kubectx
      kubelogin
      kubelogin-oidc
      (if cfg.helmPlugins == [ ] then kubernetes-helm else wrapHelm kubernetes-helm { plugins = cfg.helmPlugins; })
      stern
      helmfile
      kubetail
      lens
      kubectl-tree
    ];
    programs.k9s.enable = true;
    programs.kubecolor.enable = true;
    programs.kubecolor.enableZshIntegration = true;
  };
}
