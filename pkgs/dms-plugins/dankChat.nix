{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  python3,
  wacli,
  ffmpeg,
  wl-clipboard,
  libnotify,
  xdg-utils,
  systemd,
  ...
}:
let
  # backend/requirements.txt: telethon, qrcode[pil], pillow, pyaes, pyasn1, rsa
  pythonEnv = python3.withPackages (
    ps: with ps; [
      telethon
      qrcode
      pillow
      pyaes
      pyasn1
      rsa
    ]
  );

  # Tools the backend looks up on PATH (voice recording, clipboard paste,
  # notifications, opening files, sync unit control).
  runtimePath = lib.makeBinPath [
    ffmpeg
    wl-clipboard
    libnotify
    xdg-utils
    systemd
  ];
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "dms-plugin-dankChat";
  version = "0.6.1";

  # Same revision the dms-plugin-registry pins for "dankChat".
  src = fetchFromGitHub {
    owner = "coldi1337";
    repo = "DankChat";
    rev = "59f39c334ce61357ef1f96736aa730bf20b6e205";
    hash = "sha256-o6IeLNPVK98rGUBl33UveNojJ/sMhuOTq0iBslBYwms=";
  };

  dontConfigure = true;
  dontBuild = true;

  postPatch = ''
    # wacli: use the Nix-built binary instead of ~/.local/bin/wacli.
    substituteInPlace backend/bridge.py \
      --replace-fail 'Path.home() / ".local/bin/wacli"' 'Path("${lib.getExe wacli}")'
    substituteInPlace backend/whatsapp_sync.py \
      --replace-fail "str(Path.home() / '.local/bin/wacli')" "'${lib.getExe wacli}'"
    substituteInPlace vendor/whatsapp/bin/whatsapp_client.py \
      --replace-fail 'HOME / ".local/bin/wacli"' 'Path("${lib.getExe wacli}")' \
      --replace-fail 'Path("/usr/bin/systemctl")' 'Path("${systemd}/bin/systemctl")' \
      --replace-fail 'Path("/usr/bin/wl-paste")' 'Path("${wl-clipboard}/bin/wl-paste")' \
      --replace-fail 'Path("/usr/bin/xdg-open")' 'Path("${xdg-utils}/bin/xdg-open")' \
      --replace-fail 'Path("/usr/bin/notify-send")' 'Path("${libnotify}/bin/notify-send")'

    # Bridge and sync launchers: Nix Python env + runtime tools, no venv.
    cat > scripts/run-bridge <<EOF
    #!/bin/sh
    export PATH="${runtimePath}\''${PATH:+:\$PATH}"
    exec ${pythonEnv.interpreter} $out/backend/bridge.py
    EOF
    cat > scripts/run-whatsapp-sync <<EOF
    #!/bin/sh
    export PATH="${runtimePath}\''${PATH:+:\$PATH}"
    exec ${pythonEnv.interpreter} $out/backend/whatsapp_sync.py "\$@"
    EOF

    # Setup is done at build time; the upstream installers would try to
    # create a venv / download wacli inside the read-only plugin directory.
    for f in scripts/setup scripts/setup-telegram scripts/install-local; do
      cat > "$f" <<EOF
    #!/bin/sh
    echo "DankChat was built with Nix: Python libraries and wacli are already provided."
    echo "The WhatsApp sync units are in $out/share/systemd/user (install them via home-manager)."
    EOF
    done
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out
    cp -r . $out
    chmod +x $out/scripts/*

    # Anything still probing for the venv finds the Nix env.
    mkdir -p $out/.venv/bin
    ln -s ${pythonEnv.interpreter} $out/.venv/bin/python3
    ln -s ${pythonEnv.interpreter} $out/.venv/bin/python

    # systemd user units (upstream's install-local writes these at runtime).
    mkdir -p $out/share/systemd/user
    for unit in dankchat-whatsapp.service dankchat-whatsapp@.service; do
      arg=""
      [ "$unit" = "dankchat-whatsapp@.service" ] && arg=" %i"
      cat > $out/share/systemd/user/$unit <<EOF
    [Unit]
    Description=DankChat WhatsApp synchronization
    PartOf=dms.service
    After=network-online.target

    [Service]
    ExecStart=$out/scripts/run-whatsapp-sync$arg
    Restart=on-failure
    RestartSec=10
    UMask=0077
    NoNewPrivileges=true
    StandardOutput=null
    StandardError=null
    EOF
    done

    mkdir -p $out/share/applications
    cat > $out/share/applications/dankchat.desktop <<EOF
    [Desktop Entry]
    Type=Application
    Name=DankChat
    Comment=Telegram and WhatsApp in DankMaterialShell
    Exec=dms ipc call dankChat open
    Icon=internet-chat
    Terminal=false
    Categories=Network;InstantMessaging;
    EOF

    # Precompile so Python never tries to write __pycache__ into the store.
    ${pythonEnv.interpreter} -m compileall -q --invalidation-mode unchecked-hash $out/backend $out/vendor

    runHook postInstall
  '';

  passthru = {
    # Pinned to the revision the dms-plugin-registry uses.
    skipUpdate = true;
    inherit pythonEnv wacli;
  };

  meta = {
    description = "Telegram and WhatsApp chats in DankMaterialShell (Nix-provisioned backend)";
    homepage = "https://github.com/coldi1337/DankChat";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
})
