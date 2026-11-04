{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  writeShellScript,
  python3,
  glib,
  gobject-introspection,
  coreutils,
  gnugrep,
  gnused,
  gawk,
  iproute2,
  util-linux,
  openssl,
  keyutils,
  libnotify,
  wl-clipboard,
  xdg-utils,
  desktop-file-utils,
  ...
}:
let
  # airdrop-serve.py needs libarchive-c; pick.py needs PyGObject (Gio portal).
  pythonEnv = python3.withPackages (
    ps: with ps; [
      libarchive-c
      pygobject3
    ]
  );

  typelibPath = lib.makeSearchPath "lib/girepository-1.0" [
    glib.out
    gobject-introspection
  ];

  # Omarchy's toast command, mapped onto libnotify. omdrop calls it as
  #   omarchy-notification-send [-t MS] TITLE BODY [--image FILE] [--exec CMD...]
  notifyShim = writeShellScript "omarchy-notification-send" ''
    timeout=5000 image= title= body= exec=()
    while (( $# )); do
      case "$1" in
        -t) timeout=$2; shift 2 ;;
        --image) image=$2; shift 2 ;;
        --exec) shift; exec=("$@"); break ;;
        *) if [[ -z "$title" ]]; then title=$1; else body=$1; fi; shift ;;
      esac
    done
    args=(-a omdrop -t "$timeout")
    [[ -n "$image" ]] && args+=(-i "$image")
    if (( ''${#exec[@]} )); then
      ( action=$(${libnotify}/bin/notify-send "''${args[@]}" --action=default=Open --wait "$title" "$body")
        [[ "$action" == default ]] && exec "''${exec[@]}" ) >/dev/null 2>&1 &
    else
      exec ${libnotify}/bin/notify-send "''${args[@]}" "$title" "$body"
    fi
  '';

  # Prefixed onto the caller's PATH, so systemctl/systemd-run/journalctl/pkexec
  # keep coming from the running system (/run/current-system, /run/wrappers).
  runtimePath = lib.makeBinPath [
    pythonEnv
    coreutils
    gnugrep
    gnused
    gawk
    iproute2
    util-linux
    openssl
    keyutils
    libnotify
    wl-clipboard
    xdg-utils
    desktop-file-utils
  ];
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "omdrop";
  # dmsAirDrop's adapter refuses any other version for mutations.
  version = "0.14.1";

  src = fetchFromGitHub {
    owner = "brentkearney";
    repo = "omdrop-plugin";
    rev = "v${finalAttrs.version}";
    hash = "sha256-l1uNnDDvHW/OXNloJFJH2uSW77C+c76b0Fc9Ed0YiU8=";
  };

  buildInputs = [ pythonEnv ];

  dontBuild = true;

  # Keep the upstream plugin layout: $out/manifest.json, $out/bin/omdrop next
  # to $out/share/airdrop-receiver.service. omdrop finds its own directory by
  # walking up from $0 to the first parent holding manifest.json, and the DMS
  # plugin compares ~/.config/systemd/user/airdrop-receiver.service against
  # $out/share/airdrop-receiver.service with @PLUGIN_DIR@ replaced by $out.
  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp -r bin share manifest.json README.md LICENSE docs $out/
    mkdir -p $out/libexec/omdrop
    ln -s ${notifyShim} $out/libexec/omdrop/omarchy-notification-send
    runHook postInstall
  '';

  postFixup = ''
    # CLI: give it its tools without replacing PATH (it needs the system's
    # systemctl and the setuid pkexec wrapper).
    sed -i '/^set -uo pipefail$/a export PATH=${runtimePath}:'"$out"'/libexec/omdrop''${PATH:+:$PATH}\nexport GI_TYPELIB_PATH=${typelibPath}''${GI_TYPELIB_PATH:+:$GI_TYPELIB_PATH}' \
      $out/bin/omdrop
    grep -q '^export PATH=/nix/store' $out/bin/omdrop

    # The receiver-library probe looks for an FHS path; identity.py dlopens by soname.
    substituteInPlace $out/bin/omdrop \
      --replace-fail '/usr/lib/libkeyutils.so.1' '${lib.getLib keyutils}/lib/libkeyutils.so.1'
    substituteInPlace $out/bin/identity.py \
      --replace-fail "ctypes.CDLL('libkeyutils.so.1'" "ctypes.CDLL('${lib.getLib keyutils}/lib/libkeyutils.so.1'"

    # Receiver unit template: no /usr/bin/python3 on NixOS, and the
    # ExecStartPre shell snippets need ss/ip/grep/seq/sleep.
    substituteInPlace $out/share/airdrop-receiver.service \
      --replace-fail 'ExecStart=/usr/bin/python3 ' 'ExecStart=${pythonEnv}/bin/python3 ' \
      --replace-fail $'[Service]\n' $'[Service]\nEnvironment=PATH=${
        lib.makeBinPath [
          coreutils
          gnugrep
          iproute2
          openssl
          keyutils
        ]
      }\n'

    # Pre-rendered copy of the unit, exactly what `omdrop setup` would write to
    # ~/.config/systemd/user/, for home-manager to link (avoids omdrop writing it).
    mkdir -p $out/share/systemd/user
    substitute $out/share/airdrop-receiver.service $out/share/systemd/user/airdrop-receiver.service \
      --replace-fail '@PLUGIN_DIR@' "$out"

    # The rest of `omdrop setup`, so home-manager can do it declaratively:
    # 1. The self-signed AirDrop identity (~/.omdrop/keys). Private key, so it
    #    is generated at activation, never in the store; idempotent.
    cat > $out/libexec/omdrop/omdrop-ensure-identity <<EOF
    #!${stdenvNoCC.shell}
    export PATH=${runtimePath}\''${PATH:+:\$PATH}
    exec ${pythonEnv}/bin/python3 $out/bin/identity.py ensure-self-signed "\$@"
    EOF
    chmod +x $out/libexec/omdrop/omdrop-ensure-identity

    # 2. The handler for received .url/.webloc links (same file names as
    #    omdrop's links_install, so a later `omdrop setup` finds them in place).
    mkdir -p $out/share/applications $out/share/mime/packages
    cat > $out/share/applications/netmojo.omdrop-links.desktop <<EOF
    [Desktop Entry]
    Type=Application
    Name=Omdrop link opener
    Comment=Open a link an Apple device sent over AirDrop in the web browser
    Exec=$out/bin/omdrop open-link %f
    MimeType=application/x-mswinurl;application/x-webloc;
    NoDisplay=true
    Terminal=false
    EOF
    cat > $out/share/mime/packages/netmojo.omdrop-webloc.xml <<'EOF'
    <?xml version="1.0" encoding="UTF-8"?>
    <mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">
      <mime-type type="application/x-webloc">
        <comment>Website location</comment>
        <glob pattern="*.webloc"/>
      </mime-type>
    </mime-info>
    EOF
  '';

  meta = {
    description = "AirDrop send/receive CLI and receiver (omdrop), as expected by the DMS dmsAirDrop plugin";
    homepage = "https://github.com/brentkearney/omdrop-plugin";
    license = lib.licenses.mit;
    mainProgram = "omdrop";
    platforms = lib.platforms.linux;
  };
})
