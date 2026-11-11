# System fonts, the same on NixOS and macOS (fonts.packages exists in both).
{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.modules.fonts;
in
{
  options.modules.fonts.enable = lib.mkEnableOption "the shared set of system fonts";

  config = lib.mkIf cfg.enable {
    fonts.packages = with pkgs; [
      font-awesome
      noto-fonts-color-emoji
      meslo-lgs-nf
      # Only the Nerd Fonts in use (all of them is several GB). symbols-only
      # gives every other font the Nerd Font icons as a fallback.
      nerd-fonts.fira-code
      nerd-fonts.jetbrains-mono
      nerd-fonts.symbols-only
    ];
  };
}
