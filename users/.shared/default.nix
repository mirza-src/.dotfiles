{ self, pkgs, lib, username, ... }:
{
  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  #
  # You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then make sure to first check the Home Manager
  # release notes.
  home.stateVersion = lib.mkDefault "25.05"; # Please read the comment before changing.

  # Apply overlays to the system's pkgs.
  nixpkgs.overlays = lib.attrValues self.overlays;
  home.username = lib.mkDefault username;
  home.homeDirectory = lib.mkDefault "/home/${username}";
  nix.package = lib.mkDefault pkgs.nix;
  nixpkgs.config.allowUnfree = lib.mkDefault true;
}
