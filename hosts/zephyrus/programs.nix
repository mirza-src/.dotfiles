{ pkgs, ... }:
{
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

  programs.git.enable = true;
  programs.vim.enable = true;
  services.avahi.enable = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    # Core utilities
    git
    wget
    curl
    jq
    yq-go

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

    adwaita-icon-theme
    bitwarden-desktop
  ];
}
