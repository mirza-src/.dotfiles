# Host defaults shared by NixOS and nix-darwin. The platform halves
# (../nixos/defaults.nix, a future ../darwin/defaults.nix) add their own
# settings under the same `modules.defaults.enable`, and import the matching
# home-manager system module (home-manager.nixosModules / darwinModules).
{
  self,
  lib,
  pkgs,
  config,
  inputs,
  hostname,
  ...
}:
let
  cfg = config.modules.defaults;
in
{
  options.modules.defaults.enable = lib.mkEnableOption "default host settings";

  config = lib.mkIf cfg.enable {
    networking.hostName = lib.mkDefault hostname;

    # Apply overlays to the system's pkgs.
    nixpkgs.overlays = lib.attrValues self.overlays;
    nixpkgs.config.allowUnfree = lib.mkDefault true;

    nix.nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];
    nix.settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
    # Admin group: wheel on NixOS, admin on macOS.
    nix.settings.trusted-users = [ (if pkgs.stdenv.hostPlatform.isDarwin then "@admin" else "@wheel") ];

    home-manager.useGlobalPkgs = lib.mkDefault true;
    home-manager.useUserPackages = lib.mkDefault true;

    environment.systemPackages = with pkgs; [
      git
    ];
  };
}
