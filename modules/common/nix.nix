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
  cfg = config.modules.nix;
in
{
  options.modules.nix = {
    enable = mkEnableOption "Nix optimizations and tools";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      nil
      nixd
      alejandra
      nixfmt
      home-manager
      devenv
      vulnix
      statix
      deadnix
    ];
  };
}
