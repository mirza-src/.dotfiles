# Face authentication with Gaze (https://github.com/GunduLabs/gaze): a warm
# daemon (gazed) runs SCRFD detection + ArcFace recognition + liveness checks,
# and pam_gaze asks it over D-Bus. Face is tried first; the password always
# remains as the fallback (control = "sufficient").
#
# Enroll after rebuilding:  gaze add-face default
# Check / benchmark:        gaze auth --verbose; sudo gaze doctor --benchmark
# Models are downloaded by gazed on first use into /var/cache/gaze
# (SHA-256 verified).
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.modules.face-auth;
in
{
  imports = [
    inputs.gaze.nixosModules.default
  ];

  options.modules.face-auth = {
    enable = lib.mkEnableOption "face authentication with Gaze";

    irCamera = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "usb:3277:0060";
      description = ''
        IR camera as usb:VVVV:PPPP (stable across boots; when RGB and IR share
        one USB id, Gaze picks the mono node for IR) or a bare /dev/videoN.
        Gaze refuses symlinks such as /dev/v4l/by-path/* for authentication.
      '';
    };

    greeter = lib.mkEnableOption ''
      face login at the display manager (greetd, e.g. dms-greeter), with
      TPM-backed gnome-keyring unlock. After rebuilding, enroll the password
      once with `gaze keyring` (again after a TPM clear or password change)
    '';
  };

  config = lib.mkIf cfg.enable {
    services.gaze = {
      enable = true;
      gui.enable = true; # gaze-gui, for enrollment and status
      # Config comes only from here (/etc/gaze/config.toml read-only).
      mutableConfig = false;
      settings = lib.mkMerge [
        (lib.mkIf (cfg.irCamera != null) {
          # RGB stays "primary" (first colour camera); IR adds hybrid matching
          # and IR liveness (eye-motion check).
          cameras.ir = cfg.irCamera;
        })
        (lib.mkIf cfg.greeter {
          # Keyring unlock needs TPM-sealed templates and liveness (both
          # default on); the stored password is released only to login PAM.
          storage.encrypt_templates = true;
          storage.unlock_gnome_keyring = true;
          liveness.enabled = true;
        })
      ];
      # PAM: sudo and polkit-1 by default (services.gaze.pam.defaultServices).
    };

    # Face templates are TPM-sealed by default; this gives the TPM device
    # proper ownership and adds gazed to the tss group.
    security.tpm2.enable = true;

    # DMS lock screen (its `dankshell` PAM service, see modules/nixos/desktop.nix).
    # DMS starts this PAM session on Enter, so the scan runs on submit; DMS has
    # no concurrent face slot yet (duxlabs-dev/dux-shell#3146).
    security.pam.services.dankshell.gaze.enable = lib.mkIf config.modules.desktop.enable true;

    # Display manager login (greetd). NixOS's greetd service has no default
    # rules: its auth section is just `substack login`, where the password,
    # fingerprint and keyring rules live. The face path goes in front of it:
    #   1. pam_gaze      [success=ok default=2]  match -> 2, else skip to 4
    #   2. gnome_keyring optional use_authtok    unlock with the password Gaze
    #                                            releases from the TPM
    #   3. pam_unix      sufficient use_first_pass  verify that password and
    #                                            finish; without one, fall to 4
    #   4. login         substack                normal password path
    # A face match alone never logs in without the correct password.
    security.pam.services.greetd = lib.mkIf cfg.greeter (
      let
        loginOrder = config.security.pam.services.greetd.rules.auth.login.order;
      in
      {
        gaze = {
          enable = true;
          control = "[success=ok default=2]";
          order = loginOrder - 30;
        };
        rules.auth.gazeKeyring = {
          order = loginOrder - 20;
          control = "optional";
          modulePath = "${pkgs.gnome-keyring}/lib/security/pam_gnome_keyring.so";
          settings.use_authtok = true;
        };
        rules.auth.gazeUnix = {
          order = loginOrder - 10;
          control = "sufficient";
          modulePath = config.security.pam.pam_unixModulePath;
          settings.use_first_pass = true;
        };
        # `session include login` already starts the keyring, but `gaze doctor`
        # only accepts the hook in greetd's own file. A second auto_start is a
        # no-op once the daemon is running.
        rules.session.gazeKeyring = {
          order = config.security.pam.services.greetd.rules.session.login.order + 10;
          control = "optional";
          modulePath = "${pkgs.gnome-keyring}/lib/security/pam_gnome_keyring.so";
          settings.auto_start = true;
        };
      }
    );
  };
}
