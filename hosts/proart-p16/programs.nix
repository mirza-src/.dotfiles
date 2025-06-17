{ pkgs, lib, ... }:
{
  fonts.packages =
    with pkgs;
    [
      font-awesome
      noto-fonts-emoji
      meslo-lgs-nf
    ]
    ++ builtins.filter lib.attrsets.isDerivation (builtins.attrValues pkgs.nerd-fonts);

  programs.git.enable = true;
  programs.git.lfs.enable = true;
  programs.git.lfs.enablePureSSHTransfer = true;
  programs.git-worktree-switcher.enable = true;
  programs.vim.enable = true;
  programs.firefox.enable = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    # Core utilities
    wget
    curl

    # Device management
    fwup
    lshw
    pciutils
    usbutils

    # Development tools
    gcc
    libgcc
    gnumake
  ];
}
