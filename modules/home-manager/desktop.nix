# Per-user half of the default desktop (mango + DankMaterialShell) that the
# host enables with `modules.desktop.enable` (modules/nixos/desktop.nix).
# The host installs the shell, plugins and system backends; this adds what
# has to live in each user's home. Linux only; a no-op on macOS.
#
# Bring your own desktop: set `modules.desktop.useDefault = false`, which
# masks the host's DMS user service for this user.
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.modules.desktop;
  inherit (pkgs.stdenv.hostPlatform) isLinux;
in
{
  imports = [
    inputs.danksearch.homeModules.dsearch
  ];

  options.modules.desktop.useDefault = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Use the host's default desktop (mango + DankMaterialShell). Set to false
      to bring your own: the host's DMS user service is masked for this user.
    '';
  };

  config = lib.mkIf isLinux (
    lib.mkMerge [
      (lib.mkIf cfg.useDefault {
        programs.dsearch.enable = true; # file search for the DMS launcher

        services.gnome-keyring.enable = true;
        services.gnome-keyring.components = [
          "ssh"
          "pkcs11"
          "secrets"
        ];

        # DankChat (plugin from the host): desktop entry and WhatsApp
        # background sync units.
        xdg.dataFile."applications/dankchat.desktop".source =
          "${pkgs.dms-plugins.dankChat}/share/applications/dankchat.desktop";
        xdg.configFile."systemd/user/dankchat-whatsapp.service".source =
          "${pkgs.dms-plugins.dankChat}/share/systemd/user/dankchat-whatsapp.service";
        xdg.configFile."systemd/user/dankchat-whatsapp@.service".source =
          "${pkgs.dms-plugins.dankChat}/share/systemd/user/dankchat-whatsapp@.service";

        # AirDrop (plugin from the host), everything `omdrop setup` would do:
        # - CLI in ~/.local/bin (the plugin looks there first)
        # - receiver unit, linked as a file rather than systemd.user.services:
        #   the plugin requires it to match omdrop's template byte for byte.
        #   Not enabled; omdrop starts/stops it per receive window.
        # - self-signed AirDrop identity in ~/.omdrop/keys, created at
        #   activation (private key, so never in the store); never replaces
        #   an existing one
        home.file.".local/bin/omdrop".source = "${pkgs.omdrop}/bin/omdrop";
        xdg.configFile."systemd/user/airdrop-receiver.service".source =
          "${pkgs.omdrop}/share/systemd/user/airdrop-receiver.service";
        # - AirDrop name: the host's display name (pretty hostname, e.g.
        #   "Zephyrus G14") instead of the bare hostname. Written to the
        #   receiver's config only when it has no name yet, so `omdrop`'s own
        #   setting wins; the file stays writable for omdrop.
        # Exit codes: 0 created, 1 already present, 2 error. Without
        # accepting 1, every activation after the first stopped here.
        home.activation.omdropIdentity = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          omdropName=$(. /etc/machine-info 2>/dev/null; echo "''${PRETTY_HOSTNAME:-}")
          omdropName=''${omdropName:-$(cat /proc/sys/kernel/hostname)}
          omdropConfig="${config.xdg.configHome}/airdrop/config.toml"
          if [[ ! -v DRY_RUN ]] && ! grep -qs '^name *=' "$omdropConfig"; then
            mkdir -p "$(dirname "$omdropConfig")"
            printf 'name = "%s"\n' "$omdropName" >> "$omdropConfig"
          fi
          run ${pkgs.omdrop}/libexec/omdrop/omdrop-ensure-identity \
            --name "$omdropName" || [ $? -eq 1 ]
        '';
      })

      (lib.mkIf (!cfg.useDefault) {
        # A unit in ~/.config/systemd/user linked to /dev/null masks the
        # host's /etc/systemd/user/dms.service for this user only.
        xdg.configFile."systemd/user/dms.service".source = config.lib.file.mkOutOfStoreSymlink "/dev/null";
      })
    ]
  );
}
