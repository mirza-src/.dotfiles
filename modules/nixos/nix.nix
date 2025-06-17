{
  lib,
  pkgs,
  config,
  ...
}:
with lib;
let
  cfg = config.modules.nix;
in
{
  options.modules.nix = {
    enable = mkEnableOption "Enable Nix optimizations and tools";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      nil
      nixd
      alejandra
      nixfmt-rfc-style
      home-manager
      devenv
      vulnix
      statix
      deadnix
    ];
  };
}
