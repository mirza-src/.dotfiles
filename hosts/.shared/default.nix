{
  self,
  lib,
  inputs,
  hostname,
  nixConfig,
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
  system.stateVersion = lib.mkDefault "25.05"; # Did you read the comment?

  networking.hostName = lib.mkDefault hostname;
  # Apply overlays to the system's pkgs.
  nixpkgs.overlays = lib.attrValues self.overlays;
  nixpkgs.config.allowUnfree = lib.mkDefault true;
  nix.nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  nix.settings.trusted-users = [ "@wheel" ];
  # TODO: Possibly read substituters and public-keys from flake.nixConfig?
  nix.settings.substituters = nixConfig.extra-substituters;
  nix.settings.trusted-public-keys = nixConfig.extra-trusted-public-keys;
  home-manager.useGlobalPkgs = lib.mkDefault true;
  home-manager.useUserPackages = lib.mkDefault true;

  boot.supportedFilesystems = [ "ntfs" ];
  programs.starship = {
    enable = lib.mkDefault true;
    settings = builtins.fromTOML (builtins.readFile ../.shared/.config/starship.toml);
  };

  services.logind.settings.Login.HandleLidSwitch = "ignore";
  security.polkit.enable = true;
  programs.ssh.startAgent = true;

  virtualisation.vmVariant = {
    hardware.nvidia-container-toolkit.enable = lib.mkForce false;
  };
}
