{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  pkg-config,
  makeWrapper,
  libpcap,
  libev,
  libnl,
  python3,
  gobject-introspection,
  glib,
  bash,
  coreutils,
  gawk,
  gnugrep,
  iproute2,
  iputils,
  iw,
  networkmanager,
  procps,
  util-linux,
  openssl,
  keyutils,
  ...
}:
let
  # The omdrop-awdl tools and omdrop-discoverable run `python3` and import these.
  pythonEnv = python3.withPackages (
    ps: with ps; [
      libarchive-c
      pillow
      zeroconf
      ifaddr
      dbus-python
      pygobject3
    ]
  );

  # pkexec drops the environment, so the root helper gets an explicit PATH.
  # /run/current-system/sw/bin stays last as a fallback for anything missed.
  runtimePath = lib.makeBinPath [
    pythonEnv
    bash
    coreutils
    gawk
    gnugrep
    iproute2
    iputils
    iw
    networkmanager
    procps
    util-linux
    openssl
    keyutils
  ];
  typelibPath = lib.makeSearchPath "lib/girepository-1.0" [
    glib.out
    gobject-introspection
  ];

  # Pins from omdrop-owl v0.1.0's ./pins file.
  owl = fetchFromGitHub {
    owner = "jedbillyb";
    repo = "owl";
    rev = "832d70f815c3d4a06a02117bf0fc5e868daa1ff0";
    fetchSubmodules = true;
    hash = "sha256-wke+tR6E4mfmzlGw1tgXiYOkSxeIRvaOmOYNWXIUVR8=";
  };
  omdrop-awdl = fetchFromGitHub {
    owner = "brentkearney";
    repo = "omdrop-awdl";
    rev = "534f91a525337951ca19c311e53d333bd6d55100";
    hash = "sha256-GqxaM/5Qnj458AQPdHp1Jyfa6HK7tdybO6xDBbKUWc4=";
  };

  # omdrop-awdl's radio-independent tools, installed unmodified beside the helper.
  fromOmdropAwdl = [
    "send-to-peer"
    "airdrop-send.py"
    "awdl-af-parse.py"
    "awdl_identity.py"
    "awdl_debug.py"
    "ble-airdrop-adv.py"
    "awdl-airdrop-adv.py"
    "awdl-mdns-respond.py"
  ];
in
stdenv.mkDerivation (finalAttrs: {
  pname = "omdrop-owl";
  version = "0.1.0";

  src = fetchFromGitHub {
    owner = "t4t5";
    repo = "omdrop-owl";
    rev = "v${finalAttrs.version}";
    hash = "sha256-CNm3u2lIpQt9klvXO/nZy799LvplNeiJz5iCFWz0eDY=";
  };

  nativeBuildInputs = [
    cmake
    pkg-config
    makeWrapper
  ];

  buildInputs = [
    libpcap
    libev
    libnl
    pythonEnv
  ];

  # Build OWL out of its own (patched) tree, like upstream's PKGBUILD.
  dontUseCmakeConfigure = true;

  postUnpack = ''
    cp -r ${owl} owl
    chmod -R u+w owl
  '';

  postPatch = ''
    for p in patches/owl-*.patch; do
      echo "applying $p"
      patch -d ../owl -p1 < "$p"
    done
  '';

  buildPhase = ''
    runHook preBuild
    # googletest's cmake_minimum_required predates 3.5, which CMake 4 refuses.
    cmake -S ../owl -B ../owl-build -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_POLICY_VERSION_MINIMUM=3.5 -Wno-dev \
      -DCMAKE_C_FLAGS="-I${lib.getDev libnl}/include/libnl3"
    cmake --build ../owl-build --target owl -j$NIX_BUILD_CORES
    runHook postBuild
  '';

  doCheck = true;
  checkPhase = ''
    runHook preCheck
    case "$(../owl-build/daemon/owl -S intersect -R 12 -m 02:00:00:00:00:01 -F -E -h 2>&1 || true)" in
      *"invalid option"*|*"-R takes"*|*"-m takes"*)
        echo "owl lacks -S, -R, -m, -F or -E: the patches did not apply"; exit 1 ;;
    esac
    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall
    lib=$out/lib/omdrop

    install -Dm755 userspace/omdrop-discoverable $lib/omdrop-discoverable
    install -Dm644 userspace/owl-profiles $lib/owl-profiles
    install -Dm755 ../owl-build/daemon/owl $lib/owl
    for f in ${lib.concatStringsSep " " fromOmdropAwdl}; do
      install -Dm755 ${omdrop-awdl}/userspace/$f $lib/$f
    done
    # awdl_identity.py is a module, not a program.
    chmod 644 $lib/awdl_identity.py $lib/awdl_debug.py

    install -Dm644 packaging/omdrop-owl.policy \
      $out/share/polkit-1/actions/io.github.t4t5.omdrop-owl.policy
    install -Dm644 packaging/99-omdrop-owl-unmanaged.conf \
      $out/lib/NetworkManager/conf.d/99-omdrop-owl-unmanaged.conf
    install -Dm644 README.md $out/share/doc/omdrop-owl/README.md
    runHook postInstall
  '';

  postFixup = ''
    lib=$out/lib/omdrop

    # Root helper: called through pkexec (empty environment). Keep the script
    # itself in place (it finds owl/owl-profiles beside itself via $0 and
    # re-execs itself), and just give it a PATH.
    sed -i '/^set -uo pipefail$/a export PATH=${runtimePath}:/run/current-system/sw/bin\nexport GI_TYPELIB_PATH=${typelibPath}' \
      $lib/omdrop-discoverable
    grep -q '^export PATH=/nix/store' $lib/omdrop-discoverable

    # The polkit action is bound to the helper's real (resolved) path; omdrop
    # and send-to-peer call pkexec with the readlink -f'd path.
    substituteInPlace $out/share/polkit-1/actions/io.github.t4t5.omdrop-owl.policy \
      --replace-fail '/usr/lib/omdrop/omdrop-discoverable' "$lib/omdrop-discoverable"

    # send-to-peer runs as the user and calls pkexec (setuid, /run/wrappers/bin),
    # so prefix rather than replace PATH.
    wrapProgram $lib/send-to-peer \
      --prefix PATH : ${runtimePath} \
      --prefix GI_TYPELIB_PATH : ${typelibPath}
  '';

  meta = {
    description = "AirDrop radio backend for omdrop on non-Broadcom Wi-Fi (AWDL in userspace through OWL)";
    homepage = "https://github.com/t4t5/omdrop-owl";
    license = with lib.licenses; [
      gpl3Plus
      gpl2Only
      isc
    ];
    platforms = lib.platforms.linux;
  };

  # Pinned: upstream became t4t5/owly (as of v0.4.3), dropping ./pins and the owl
  # patches this package builds from; moving to it needs repackaging.
  passthru.skipUpdate = true;
})
