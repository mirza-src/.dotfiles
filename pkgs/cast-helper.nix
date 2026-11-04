{
  lib,
  buildGoModule,
  fetchFromGitHub,
  makeWrapper,
  patchelf,
  glib,
  gst_all_1,
  pipewire,
  pulseaudio,
  libheif,
  doubletake,
  ...
}:
let
  # Loaded at run time through purego (dlopen), not linked.
  dlopenLibs = [
    glib
    gst_all_1.gstreamer
    gst_all_1.gst-plugins-base
  ];

  gstPlugins = [
    gst_all_1.gstreamer
    gst_all_1.gst-plugins-base # videoconvert, appsink, decodebin, opusenc, ...
    gst_all_1.gst-plugins-good # matroskademux, mp4mux, jpeg/png, ...
    gst_all_1.gst-plugins-bad # h264parse/h265parse, va (vah264enc, vapostproc)
    gst_all_1.gst-libav # avenc_aac
    pipewire # pipewiresrc
  ];

  runtimeTools = [
    pipewire # pw-metadata (sound on the TV only)
    gst_all_1.gstreamer # gst-launch-1.0 / gst-inspect-1.0, used by doubletake (AirPlay)
    pulseaudio # pactl, used by doubletake (AirPlay)
    libheif # heif-dec (HEIC photos)
    doubletake # AirPlay mirroring (wrapped with its own gst-launch-1.0, pactl and plugins)
  ];
in
buildGoModule (finalAttrs: {
  pname = "cast-helper";
  version = "0.1.0";

  src = fetchFromGitHub {
    owner = "Conava";
    repo = "dux-cast";
    tag = "v${finalAttrs.version}";
    hash = "sha256-hF7a2kQmkTm2YxS7LFvul8V5iS8FZ/fGlgLTypcEOz4=";
  };

  vendorHash = "sha256-JdnJBwV2DHo/1EZ5v6bxC1JK/5PUIZeRmjroMnZrQoQ=";

  # Keep cgo on: purego then uses the real libc dlopen, and the binary gets a
  # proper Nix store interpreter instead of /lib64/ld-linux-x86-64.so.2.
  env.CGO_ENABLED = 1;

  ldflags = [
    "-s"
    "-w"
  ];

  nativeBuildInputs = [
    makeWrapper
    patchelf
  ];

  # Offer windows as well as monitors in the screen-share portal (upstream asks
  # for monitors only).
  postPatch = ''
    substituteInPlace portal.go \
      --replace-fail '"types":        dbus.MakeVariant(uint32(1)), // monitor' \
                     '"types":        dbus.MakeVariant(uint32(3)), // monitor | window'
  '';

  # Tests probe GStreamer elements and the network.
  doCheck = false;

  postInstall = ''
    mv $out/bin/dux-cast $out/bin/cast-helper
  '';

  postFixup = ''
    patchelf --add-rpath ${lib.makeLibraryPath dlopenLibs} $out/bin/cast-helper
    wrapProgram $out/bin/cast-helper \
      --prefix PATH : ${lib.makeBinPath (map lib.getBin runtimeTools)} \
      --prefix GST_PLUGIN_SYSTEM_PATH_1_0 : ${lib.makeSearchPathOutput "lib" "lib/gstreamer-1.0" gstPlugins}
  '';

  meta = {
    description = "Cast screen, files, music and links to Chromecast and AirPlay devices (backend of the DMS Cast plugin)";
    homepage = "https://github.com/Conava/dux-cast";
    license = lib.licenses.mit;
    mainProgram = "cast-helper";
    platforms = lib.platforms.linux;
  };
})
