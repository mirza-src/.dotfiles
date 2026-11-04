# NixOS half of the host defaults; the shared half (nix settings, overlays,
# hostname, home-manager) is ../common/defaults.nix, which declares
# `modules.defaults.enable`.
{
  lib,
  pkgs,
  config,
  inputs,
  ...
}:
let
  cfg = config.modules.defaults;
in
{
  imports = [
    inputs.home-manager.nixosModules.home-manager
  ];

  config = lib.mkIf cfg.enable {
    # This value determines the NixOS release from which the default
    # settings for stateful data, like file locations and database versions
    # on your system were taken. It‘s perfectly fine and recommended to leave
    # this value at the release version of the first install of this system.
    # Before changing this value read the documentation for this option
    # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
    system.stateVersion = lib.mkDefault "25.05"; # Did you read the comment?

    boot.supportedFilesystems = [ "ntfs" ];

    services.logind.settings.Login = {
      HandlePowerKey = "hibernate";
      HandleSuspendKey = "sleep";
      HandleLidSwitch = "ignore";
    };
    services.fprintd.enable = true;
    services.hardware.bolt.enable = true;
    services.accounts-daemon.enable = true;
    environment.systemPackages = with pkgs; [
      ryzenadj
      kdiskmark
    ];

    programs.nix-ld.enable = true;
    programs.nix-ld.libraries = with pkgs; [
      libGL
    ];
  };
}
