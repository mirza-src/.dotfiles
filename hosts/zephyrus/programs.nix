{ pkgs, lib, ... }:
{
  fonts.packages =
    with pkgs;
    [
      font-awesome
      noto-fonts-color-emoji
      meslo-lgs-nf
    ]
    ++ builtins.filter lib.attrsets.isDerivation (builtins.attrValues pkgs.nerd-fonts);

  programs.git.enable = true;
  programs.vim.enable = true;

  programs.anime-games-launcher.enable = false;
  programs.anime-game-launcher.enable = true;
  programs.honkers-launcher.enable = true;
  programs.honkers-railway-launcher.enable = true;
  programs.wavey-launcher.enable = true;
  programs.sleepy-launcher.enable = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    # Core utilities
    git
    wget
    curl
    jq
    yq

    # Device management
    acpi
    fwup
    lshw
    pciutils
    usbutils

    # Networking tools
    inetutils
    nettools
    dnsutils
    tcpdump

    # Development tools
    gcc
    libgcc
    gnumake

    # Disk management
    libbde
    cryptsetup
    dislocker
    gparted
  ];
}
