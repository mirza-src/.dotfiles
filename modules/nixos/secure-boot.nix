{
  lib,
  pkgs,
  config,
  inputs,
  ...
}:
with lib;
let
  cfg = config.modules.secure-boot;
in
{
  imports = [
    inputs.lanzaboote.nixosModules.lanzaboote
  ];

  options.modules.secure-boot = {
    enable = mkEnableOption "Enable Secure Boot Options";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      # Does not support DBX: https://github.com/Foxboron/sbctl/issues/23
      sbctl
      sbsigntool
      efivar
      efitools
      efibootmgr
      tpm-tools
      tpm2-tools
    ];

    boot.lanzaboote = {
      enable = true;
      pkiBundle = "/var/lib/sbctl"; # TODO: https://github.com/nix-community/lanzaboote/issues/414
      settings = {
        # TODO: Support windows dual boot
        # https://github.com/nix-community/lanzaboote/issues/271
        # https://github.com/nix-community/lanzaboote/issues/427
        reboot-for-bitlocker = true;
      };
    };

    # Disable other boot loaders to avoid conflicts with lanzaboote.
    boot.loader.systemd-boot.enable = false;
    boot.loader.grub.enable = false;
  };
}
