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
      HandleSuspendKey = "suspend";
      HandleLidSwitch = "suspend";
      HandleLidSwitchDocked = "ignore";
      HandleLidSwitchExternalPower = "ignore";
    };
    services.fprintd.enable = true;
    services.hardware.bolt.enable = true;
    services.accounts-daemon.enable = true;
    environment.systemPackages = with pkgs; [
      ryzenadj
      kdiskmark
    ];

    # GitHub token for fetchFromGitHub { private = true; } sources. Builds run
    # in the daemon, so it needs it, not your shell. "-": optional file.
    # Needed by: opsctl (nix-gs)
    # 1. Open the link, then Repository access -> Only select repositories ->
    #    the repos above (the URL can't pre-select them), Generate:
    #    https://github.com/settings/personal-access-tokens/new?name=nix-daemon&description=nix-daemon%20private%20sources&target_name=giantswarm&expires_in=90&contents=read
    # 2. read -rs "token?Token: " && printf 'NIX_GITHUB_PRIVATE_USERNAME=%s\nNIX_GITHUB_PRIVATE_PASSWORD=%s\n' \
    #      "$(gh api user -q .login)" "$token" | sudo sh -c 'umask 077; cat > /etc/nix/github-private.env'
    #    Or skip 1 and use your gh login (full access, no expiry): token=$(gh auth token)
    # 3. sudo systemctl restart nix-daemon
    systemd.services.nix-daemon.serviceConfig.EnvironmentFile = "-/etc/nix/github-private.env";

    programs.nix-ld.enable = true;
    programs.nix-ld.libraries = with pkgs; [
      libGL
    ];
  };
}
