{
  lib,
  pkgs,
  config,
  ...
}:
with lib;
let
  cfg = config.modules.kubernetes;
in
{
  options.modules.kubernetes = {
    enable = mkEnableOption "Enable Kubernetes tools";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      kubectl
      kubectx
      kubelogin
      kubelogin-oidc
      kubernetes-helm
      stern
      helmfile
      kubetail
      lens
    ];
    programs.k9s.enable = true;
    programs.kubecolor.enable = true;
    programs.kubecolor.enableZshIntegration = true;
  };
}
