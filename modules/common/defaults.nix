# Host defaults shared by NixOS and nix-darwin. The platform halves
# (../nixos/defaults.nix, ../darwin/defaults.nix) add their own settings under
# the same `modules.defaults.enable`. Home-manager runs standalone
# (homeConfigurations in flake.nix), not as a system module.
{
  self,
  lib,
  pkgs,
  config,
  inputs,
  hostname,
  nixConfig,
  ...
}:
let
  cfg = config.modules.defaults;
  inherit (pkgs.stdenv.hostPlatform) isDarwin;
in
{
  options.modules.defaults = {
    enable = lib.mkEnableOption "default host settings";

    primaryUser = lib.mkOption {
      type = lib.types.str;
      example = "mirza";
      description = "The machine's main user: owns the dotfiles checkout and the desktop/macOS settings.";
    };

    displayName = lib.mkOption {
      type = lib.types.str;
      default = lib.toUpper (lib.substring 0 1 hostname) + lib.substring 1 (-1) hostname;
      defaultText = lib.literalMD "the hostname, capitalised";
      example = "Zephyrus G14";
      description = ''
        Human-readable machine name, shown in AirDrop, Bluetooth and network
        sharing (macOS ComputerName, systemd's pretty hostname). The hostname
        itself stays lowercase.
      '';
    };

    flake = lib.mkOption {
      type = lib.types.str;
      default = "${if isDarwin then "/Users" else "/home"}/${cfg.primaryUser}/.dotfiles";
      defaultText = lib.literalExpression ''"<home of primaryUser>/.dotfiles"'';
      description = "Path of this repository's checkout, used by nh.";
    };
  };

  config = lib.mkIf cfg.enable {
    networking.hostName = lib.mkDefault hostname;

    # Apply overlays to the system's pkgs.
    nixpkgs.overlays = lib.attrValues self.overlays;
    nixpkgs.config.allowUnfree = lib.mkDefault true;

    # Git commit of this repo, shown by nixos-version / darwin-version.
    system.configurationRevision = self.rev or self.dirtyRev or null;

    nix.nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];
    nix.settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
    # Admin group: wheel on NixOS, admin on macOS.
    nix.settings.trusted-users = [ (if isDarwin then "@admin" else "@wheel") ];
    # The flake's binary caches, for the daemon itself: without them a skipped
    # accept-flake-config prompt means building e.g. the CachyOS kernel locally.
    nix.settings.extra-substituters = nixConfig.extra-substituters;
    nix.settings.extra-trusted-public-keys = nixConfig.extra-trusted-public-keys;

    # Hard-link identical store files (periodic, not on every build).
    nix.optimise.automatic = true;

    # nh: nicer rebuilds (`nh os switch` / `nh darwin switch`, `nh home switch`)
    # and a weekly cleanup of old system and user (incl. home-manager)
    # generations.
    programs.nh = {
      enable = true;
      inherit (cfg) flake;
      clean = {
        enable = true;
        extraArgs = "--keep 5 --keep-since 7d";
      };
    };

    environment.systemPackages = with pkgs; [
      git
    ];
  };
}
