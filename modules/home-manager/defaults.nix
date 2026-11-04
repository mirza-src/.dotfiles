{
  self,
  pkgs,
  lib,
  config,
  username,
  ...
}:
let
  cfg = config.modules.defaults;
  inherit (pkgs.stdenv.hostPlatform) isDarwin isLinux;
in
{
  options.modules.defaults.enable = lib.mkEnableOption "default user settings";

  config = lib.mkMerge [
    {
      # Helpers for linking files from this repo into $HOME.
      lib.dotfiles = rec {
        # A symlink into the checkout at ~/.dotfiles (not the store), so the
        # file stays writable and edits land in the repo.
        mkMutableSymlink =
          path:
          config.lib.file.mkOutOfStoreSymlink (
            "${config.home.homeDirectory}/.dotfiles" + lib.removePrefix (toString self) (toString path)
          );

        # xdg.configFile entries: writable symlinks for every file in the listed
        # folders (or single files) under a `.config` directory, each linked to
        # the same path under ~/.config, e.g.
        #   xdg.configFile = linkDirs [ ./.config/kitty ./.config/dms ];
        # Paths are literals, so editors complete them and a missing one fails
        # evaluation. Files are linked one by one (not the folder itself) so
        # apps can't write their own runtime files into the repo.
        linkDirs =
          paths:
          lib.listToAttrs (
            map (
              file:
              let
                parts = lib.splitString "/.config/" (toString file);
              in
              assert lib.assertMsg (
                lib.length parts > 1
              ) "lib.dotfiles.linkDirs: ${toString file} is not under a .config directory";
              {
                name = lib.last parts;
                value.source = mkMutableSymlink file;
              }
            ) (
              lib.concatMap (
                path: if lib.pathIsDirectory path then lib.filesystem.listFilesRecursive path else [ path ]
              ) paths
            )
          );
      };
    }

    (lib.mkIf cfg.enable {
      # This value determines the Home Manager release that your configuration is
      # compatible with. This helps avoid breakage when a new Home Manager release
      # introduces backwards incompatible changes.
      #
      # You should not change this value, even if you update Home Manager. If you do
      # want to update the value, then make sure to first check the Home Manager
      # release notes.
      home.stateVersion = lib.mkDefault "26.05"; # Please read the comment before changing.

      home.username = lib.mkDefault username;
      home.homeDirectory = lib.mkDefault (
        if isDarwin then "/Users/${username}" else "/home/${username}"
      );
      nix.package = lib.mkDefault pkgs.nix;
      nixpkgs.config.allowUnfree = lib.mkDefault true;
      nixpkgs.config.cudaSupport = lib.mkDefault isLinux;
      nixpkgs.config.permittedInsecurePackages = [
        "electron-39.8.10"
      ];
    })
  ];
}
