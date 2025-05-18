{ ... }: {
  imports = [
    # ../../modules/nixos/disk-config.nix
    # ../../modules/shared
    ../../modules/nixos/nvidia.nix
    # Include the results of the hardware scan.
    /etc/nixos/hardware-configuration.nix

    ./audio.nix
    ./battery.nix
    ./boot.nix
    ./desktop.nix
    ./graphics.nix
    ./locale.nix
    ./networking.nix
    ./programs.nix
  ];
  
  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.nvidia.acceptLicense = true;
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # Enable CUPS to print documents.
  services.printing.enable = true;

  services.logind.lidSwitch = "ignore";
  

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.11"; # Did you read the comment?
}
