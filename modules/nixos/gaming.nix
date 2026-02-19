{
  lib,
  pkgs,
  config,
  inputs,
  ...
}:
with lib;
let
  cfg = config.modules.gaming;
in
{
  imports = [
    inputs.nix-gaming.nixosModules.platformOptimizations
  ];

  options.modules.gaming = {
    enable = mkEnableOption "Enable gaming optimizations and tools";
  };

  config = mkIf cfg.enable {
    programs.gamemode.enable = true;
    programs.gamescope = {
      enable = true;
      capSysNice = true;
    };
    # programs.lutris.enable = true;
    programs.steam = {
      enable = true;
      package = pkgs.steam.override {
        extraPkgs =
          pkgs: with pkgs; [
            gamescope
            mangohud
          ];
      };

      platformOptimizations.enable = true;
      gamescopeSession.enable = true;
      gamescopeSession.args = [
        "--adaptive-sync" # VRR support
        "--hdr-enabled" # HDR support
        "--mangoapp" # performance overlay
        "--rt" # Use realtime scheduling
        # Integrated GPU
        # "--prefer-vk-device"
        # "1002:150e"
      ];
      remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
      dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server
      localNetworkGameTransfers.openFirewall = true; # Open ports in the firewall for Steam Local Network Game Transfers
    };
  };
}
