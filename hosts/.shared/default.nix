{
  self,
  lib,
  inputs,
  hostname,
  ...
}:
{
  imports = [
    inputs.home-manager.nixosModules.home-manager
  ];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = lib.mkDefault "24.11"; # Did you read the comment?

  networking.hostName = lib.mkDefault hostname;
  # Apply overlays to the system's pkgs.
  nixpkgs.overlays = lib.attrValues self.overlays;
  nixpkgs.config.allowUnfree = lib.mkDefault true;
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  nix.settings.trusted-users = [ "@wheel" ];
  nix.settings.substituters = [
    "https://nix-community.cachix.org"
    "https://chaotic-nyx.cachix.org/"
    "https://nix-gaming.cachix.org"
    "https://nixpkgs-wayland.cachix.org"
    "https://hyprland.cachix.org"
    "https://ezkea.cachix.org"
    "https://devenv.cachix.org"
  ];
  nix.settings.trusted-public-keys = [
    "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    "chaotic-nyx.cachix.org-1:HfnXSw4pj95iI/n17rIDy40agHj12WfF+Gqk6SonIT8="
    "nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svXaZF/Ees8vCUUs4="
    "nixpkgs-wayland.cachix.org-1:3lwxaILxMRkVhehr5StQprHdEo4IrE8sRho9R9HOLYA="
    "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
    "ezkea.cachix.org-1:ioBmUbJTZIKsHmWWXPe1FSFbeVe+afhfgqgTSNd34eI="
    "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
  ];
  home-manager.useGlobalPkgs = lib.mkDefault true;
  home-manager.useUserPackages = lib.mkDefault true;

  programs.starship = {
    enable = lib.mkDefault true;
    settings = builtins.fromTOML (builtins.readFile ../.shared/.config/starship.toml);
  };

  services.logind.lidSwitch = "ignore";
  security.polkit.enable = true;

  virtualisation.vmVariant = {
    hardware.nvidia-container-toolkit.enable = lib.mkForce false;
  };
}
