{ pkgs, ... }:
{
  modules.fonts.enable = true;

  programs.git.enable = true;
  programs.vim.enable = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    # Core utilities (git comes from programs.git)
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
  ];
}
