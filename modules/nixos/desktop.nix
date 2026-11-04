# The default desktop: mango (managed by uwsm) + DankMaterialShell, with
# dms-greeter as the display manager and DMS plugins installed system-wide.
#
# Users get it by default. A user who brings their own shell/compositor sets
# `modules.desktop.useDefault = false` in home-manager, which masks the DMS
# user service for them (modules/home-manager/desktop.nix). Personal DMS and
# mango config (settings.json, plugin_settings.json, mango/config.conf) stays
# in each user's home-manager.
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.modules.desktop;
  system = pkgs.stdenv.hostPlatform.system;
  dmsPackage = inputs.dank-material-shell.packages.${system}.dms-shell;
  dmsPlugins = inputs.dms-plugin-registry.packages.${system};

  # DMS runs Qt with the gtk3 platform theme, so any file dialog a plugin
  # opens (e.g. AirDrop "Send file") is GTK's chooser in the shell process.
  # Without its GSettings schemas GLib aborts and takes DMS down with it.
  gsettingsSchemas = pkgs.runCommand "dms-gsettings-schemas" { nativeBuildInputs = [ pkgs.glib ]; } ''
    mkdir -p $out
    cp ${pkgs.glib.getSchemaPath pkgs.gtk3}/*.xml $out/
    cp ${pkgs.glib.getSchemaPath pkgs.gsettings-desktop-schemas}/*.xml $out/
    glib-compile-schemas $out
  '';
in
{
  imports = [
    inputs.mangowm.nixosModules.mango
    inputs.dank-greeter.nixosModules.default
    inputs.dank-material-shell.nixosModules.dank-material-shell
    inputs.dms-plugin-registry.nixosModules.default
  ];

  options.modules.desktop.enable = lib.mkEnableOption "the default desktop (mango + DankMaterialShell + dms-greeter)";

  config = lib.mkIf cfg.enable {
    # ── Compositor, session and display manager ──────────────────────
    programs.mango.enable = true;
    programs.uwsm = {
      enable = true;
      waylandCompositors.mango = {
        prettyName = "Mango";
        comment = "Mango Compositor managed by UWSM";
        binPath = "${pkgs.mango}/bin/mango";
      };
    };
    environment.sessionVariables.UWSM_SILENT_START = "1";

    programs.dms-greeter = {
      enable = true;
      compositor.name = lib.mkDefault "mango";
    };

    security.polkit.enable = true;
    security.pam.services.login.enableGnomeKeyring = true;
    security.pam.services.greetd.enableGnomeKeyring = true;
    # DMS lock screen: uses /etc/pam.d/dankshell when it exists (else `login`),
    # so lock-screen auth (e.g. Gaze face unlock) can differ from TTY login.
    # No fprintd here: DMS runs fingerprint as its own separate PAM prompt.
    security.pam.services.dankshell.fprintAuth = false;

    # ── Portals: screen sharing ──────────────────────────────────────
    xdg.portal = {
      xdgOpenUsePortal = true;
      # Screen-share picker via the DMS screencastPicker plugin.
      wlr.settings.screencast = {
        chooser_type = "dmenu"; # only mode that offers windows as well as monitors
        chooser_cmd = "${dmsPlugins.screencastPicker}/bin/screencast-picker";
      };
    };
    # Picker talks to DMS over IPC and grabs window thumbnails with grim.
    systemd.user.services.xdg-desktop-portal-wlr.path = [
      pkgs.grim
      dmsPackage
    ];

    # ── Shell: DankMaterialShell ─────────────────────────────────────
    programs.dank-material-shell = {
      enable = true;
      package = dmsPackage;
      systemd = {
        enable = true; # user service, bound to graphical-session.target
        restartIfChanged = true;
      };
      # Installed to /etc/xdg/quickshell/dms-plugins. Each user enables the
      # ones they want in their own ~/.config/dms/plugin_settings.json.
      # Plugin code comes from dms-plugin-registry unless src is overridden
      # (mkForce: the registry module sets src at the same priority).
      plugins = {
        screencastPicker.enable = true;
        rogControl = {
          enable = true; # asusctl: platform profile, Aura RGB, charge limit
          # Patched bar pill: with "Show platform profile in bar" on (default),
          # show only the performance-profile icon (no keyboard icon or
          # brightness bars), and use the pointing-hand cursor like other
          # widgets (its scroll MouseArea covered the pill with the default arrow).
          src = lib.mkForce (
            dmsPlugins.rogControl.overrideAttrs (old: {
              postPatch = (old.postPatch or "") + ''
                substituteInPlace RogControlWidget.qml \
                  --replace-fail 'name: svc.available ? "keyboard" : "keyboard_off"' \
                                 'visible: !(svc.showProfileInBar && svc.hasPlatform); name: svc.available ? "keyboard" : "keyboard_off"' \
                  --replace-fail 'model: Math.max(0, svc.kbSupportedBrightness.length - 1)' \
                                 'model: (svc.showProfileInBar && svc.hasPlatform) ? 0 : Math.max(0, svc.kbSupportedBrightness.length - 1)' \
                  --replace-fail 'acceptedButtons: Qt.NoButton' \
                                 'acceptedButtons: Qt.NoButton; cursorShape: Qt.PointingHandCursor'
              '';
            })
          );
        };
        emojiLauncher.enable = true;
        gitmojiLauncher.enable = true;
        quickCapture.enable = true; # screenshots, recordings, OCR, QR scan
        dankKDEConnect.enable = true; # Phone Connect (programs.kdeconnect below)
        aiOverviewControl.enable = true; # Claude limits + local Ollama models
        dmsThemeSync.enable = true; # apply DMS theme to GTK/Qt/KDE/fontconfig
        bitwarden = {
          enable = true; # Bitwarden Dankbar (bitwarden-cli)
          # Rust vault/unlock-key/ssh-agent helpers built in Nix (upstream
          # builds them in the plugin dir at runtime).
          src = lib.mkForce pkgs.dms-plugins.bitwarden;
        };
        cast.enable = true; # cast-helper from pkgs/
        dankTranslate.enable = true;
        developerUtilities.enable = true;
        nixPackageRunner.enable = true;
        dankChat = {
          enable = true;
          src = lib.mkForce pkgs.dms-plugins.dankChat; # Nix Python env + wacli, no runtime setup
        };
        dmsAirDrop.enable = true; # omdrop + omdrop-owl from pkgs/
      };
    };
    systemd.user.services.dms.environment.GSETTINGS_SCHEMA_DIR = "${gsettingsSchemas}";
    # The DMS NixOS module defaults power-profiles-daemon on; with TLP its
    # `pd` option provides the same D-Bus interface, and the two conflict.
    services.power-profiles-daemon.enable = lib.mkIf config.services.tlp.enable false;

    environment.systemPackages = with pkgs; [
      app2unit # DMS launchPrefix (each user's dms/settings.json)
      xwayland-satellite
      wl-clipboard
      cliphist

      # DMS plugin dependencies
      translate-shell # dankTranslate
      tesseract # quickCapture
      gpu-screen-recorder # quickCapture
      wf-recorder # quickCapture
      imagemagick # quickCapture
      img2pdf # quickCapture
      zbar # quickCapture
      ffmpeg # quickCapture, dankChat
      libsecret # aiOverviewControl (secret-tool)
      sqlite # aiOverviewControl
      cast-helper # cast
      libnotify # bitwarden: notify-send
      omdrop-owl # dmsAirDrop radio helper; installs its polkit action
      # dmsAirDrop: only omdrop's link handler desktop entry + MIME type (not
      # its helper scripts, which would land on PATH)
      (runCommand "omdrop-link-handler" { } ''
        mkdir -p $out/share/applications $out/share/mime/packages
        ln -s ${omdrop}/share/applications/netmojo.omdrop-links.desktop $out/share/applications/
        ln -s ${omdrop}/share/mime/packages/netmojo.omdrop-webloc.xml $out/share/mime/packages/
      '')
    ];

    # ── Plugin backends that need the system ─────────────────────────
    # Phone Connect: KDE Connect daemon, opens TCP/UDP 1714-1764.
    programs.kdeconnect.enable = true;

    # Cast: Chromecast fetches local media from cast-helper; AirPlay (doubletake).
    networking.firewall.allowedTCPPorts = [ 47830 ];
    networking.firewall.allowedUDPPortRanges = [
      {
        from = 47840;
        to = 47849;
      }
    ];

    # AirDrop (omdrop + OWL). The radio helper needs root; upstream's polkit
    # action lets the active local session pkexec exactly that helper.
    systemd.tmpfiles.rules = [
      # Hardcoded in the plugin (scripts/backend.py) and omdrop (bin/omdrop)
      "L+ /usr/lib/omdrop - - - - ${pkgs.omdrop-owl}/lib/omdrop"
    ];
    networking.networkmanager.unmanaged = [
      "interface-name:awdl0"
      "interface-name:mon0"
      "interface-name:awdlibss0"
    ];
    networking.firewall.interfaces.awdl0.allowedTCPPorts = [ 8771 ]; # omdrop receiver
  };
}
