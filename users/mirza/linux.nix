# Linux-only home-manager config. The desktop itself (mango + DMS) comes from
# the host; its per-user half is modules/home-manager/desktop.nix, on by
# default (modules.desktop.useDefault).
{
  config,
  lib,
  pkgs,
  ...
}:
lib.mkIf pkgs.stdenv.hostPlatform.isLinux {

  programs.vscode.package = pkgs.vscode.fhsWithPackages (
    pkgs: with pkgs; [
      stdenv.cc.cc.lib
      libuuid
    ]
  );

  # Obsidian's config dir has to exist before the vault module writes to it.
  home.activation.createObsidianDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p ${config.xdg.configHome}/obsidian
  '';

  home.packages = with pkgs; [
    i2c-tools
    gcr_4 # GNOME keyring prompts (gcr-prompter)

    # Graphical applications (macOS equivalents in darwin.nix)
    libreoffice
    vlc
    ghostty
    veracrypt
    protonplus
    rocketchat-desktop
    kdePackages.dolphin
    kdePackages.ark
  ];

  # Linux-only app configs from ./.config (writable symlinks into this repo).
  # VS Code's settings are linked on macOS too, under ~/Library (darwin.nix).
  xdg.configFile = config.lib.dotfiles.linkDirs [
    ./.config/dms
    ./.config/mango
    ./.config/Code
    (./.config + "/Code - Insiders") # path literals can't contain spaces
  ];
}
