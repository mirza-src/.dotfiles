{
  lib,
  stdenv,
  fetchFromGitHub,
  buildDotnetModule,
  dotnetCorePackages,
  bash,
  coreutils,
  gawk,
  gnugrep,
  gnused,
  kmod,
  wlr-randr,
  libnotify,
  polkit,
  power-profiles-daemon,
  procps,
  systemd,
  usbutils,
  util-linux,
  which,
  libice,
  libsm,
  libx11,
  libxcursor,
  libxi,
  libxext,
  libxrandr,
  libxcb,
  xinput,
  xrandr,
  kdePackages,
  gnome-control-center,
  wayland,
  clang,
  zlib,
  gtk4,
}:

let
  sharedLibraries = [
    stdenv.cc.cc.lib
    zlib
    libnotify
    polkit
    power-profiles-daemon
    procps
    systemd
    util-linux
    libice
    libsm
    libx11
    libxcursor
    libxi
    libxext
    libxrandr
    libxcb
    kdePackages.libkscreen
  ];

  runtimeTools = [
    wlr-randr
    bash
    coreutils
    gawk
    gnugrep
    gnused
    kmod
    libnotify
    polkit
    power-profiles-daemon
    procps
    systemd
    usbutils
    util-linux
    which
    xinput
    xrandr
    kdePackages.kscreen
    gnome-control-center
  ];
in
buildDotnetModule (finalAttrs: {
  pname = "ghelper";
  version = "1.0.83";

  src = fetchFromGitHub {
    owner = "utajum";
    repo = "g-helper-linux";
    # rev = "v${finalAttrs.version}";
    rev = "03130d43de1bd98b73b755cfde4f0bfb3b167985";
    hash = "sha256-axRKNDE525dDCevDG1nT9JwVdpKxBneacRx4+A6PaDU=";
  };

  projectFile = "src/GHelper.Linux.csproj";
  nugetDeps = ./nuget-deps.json;

  dotnet-sdk = dotnetCorePackages.sdk_10_0;
  selfContainedBuild = true;
  executables = [
    "ghelper"
  ];

  nativeBuildInputs = [
    gtk4
    clang
    wayland
  ];

  buildInputs = [
    wayland
  ];

  runtimeDeps = sharedLibraries;

  makeWrapperArgs = [
    "--prefix"
    "PATH"
    ":"
    (lib.makeBinPath runtimeTools)
  ];

  postPatch = ''
    # Replace version placeholder in project file and udev rules with actual version
    substituteInPlace src/GHelper.Linux.csproj \
      --replace-fail "<Version>1.0.0</Version>" "<Version>${finalAttrs.version}</Version>"
    substituteInPlace install/90-ghelper.rules \
      --replace-fail VERSION_PLACEHOLDER ${finalAttrs.version}

    # Replace hardcoded paths in udev rules with correct paths to dependencies
    substituteInPlace install/90-ghelper.rules \
      --replace-fail /bin/chmod chmod \
      --replace-fail /bin/sh ${bash}/bin/sh
    substituteInPlace install/90-ghelper.rules \
      --replace-fail chmod ${coreutils}/bin/chmod
  '';

  postInstall = ''
    install -Dm644 install/ghelper.desktop $out/share/applications/ghelper.desktop
    install -Dm644 install/ghelper.appdata.xml $out/share/metainfo/ghelper.appdata.xml
    install -Dm644 install/ghelper.png $out/share/icons/hicolor/64x64/apps/ghelper.png

    install -Dm755 install/ghelper-gpu-boot.sh $out/libexec/ghelper/ghelper-gpu-boot.sh
    install -Dm755 install/gpu-block-helper.sh $out/libexec/ghelper/gpu-block-helper.sh

    substituteInPlace install/ghelper-gpu-boot.service \
      --replace-fail /usr/local/lib/ghelper/ghelper-gpu-boot.sh $out/libexec/ghelper/ghelper-gpu-boot.sh
    install -Dm644 install/ghelper-gpu-boot.service $out/lib/systemd/system/ghelper-gpu-boot.service

    install -Dm644 install/90-ghelper.rules $out/lib/udev/rules.d/90-ghelper.rules

    gtk4-update-icon-cache -qtf $out/share/icons/hicolor
  '';

  meta = with lib; {
    description = "ASUS laptop control utility for Linux";
    homepage = "https://g-helper-linux.elevatech.xyz";
    license = licenses.gpl3Plus;
    mainProgram = "ghelper";
    platforms = [ "x86_64-linux" ];
  };
})
