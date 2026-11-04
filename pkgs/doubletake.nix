{
  lib,
  buildGoModule,
  fetchFromGitHub,
  makeWrapper,
  installShellFiles,
  gst_all_1,
  pipewire,
  pulseaudio,
  ...
}:
let
  # doubletake builds its capture/encode pipelines by running gst-launch-1.0
  # and probes elements with gst-inspect-1.0.
  gstPlugins = [
    gst_all_1.gstreamer
    gst_all_1.gst-plugins-base # videoconvert, videoscale, videorate, audioconvert
    gst_all_1.gst-plugins-good # pulsesrc, rtpL16pay, rtph264pay, rtpstreampay
    gst_all_1.gst-plugins-bad # h264parse/h265parse, va encoders, vulkan, nvcodec, openh264, rtponviftimestamp
    gst_all_1.gst-plugins-ugly # x264enc (software fallback)
    pipewire # pipewiresrc
  ];

  runtimeTools = [
    gst_all_1.gstreamer # gst-launch-1.0, gst-inspect-1.0
    pulseaudio # pactl (default sink lookup for audio capture)
  ];
in
buildGoModule (finalAttrs: {
  pname = "doubletake";
  version = "0.5.0";

  src = fetchFromGitHub {
    owner = "omarroth";
    repo = "doubletake";
    tag = "v${finalAttrs.version}";
    hash = "sha256-rsxZ/UL4Pv32+timlohcue0GZcZOrAIrUkR1FX6CyTI=";
  };

  vendorHash = "sha256-cgvY9MVGe8I3g3Ni2sGucTY6YCyPJ2YnoxxUaYfl1E4=";

  subPackages = [
    "cmd/doubletake"
    "cmd/doubletake-ctl"
    "cmd/doubletake-test-receiver"
  ];

  ldflags = [
    "-s"
    "-w"
  ];

  nativeBuildInputs = [
    makeWrapper
    installShellFiles
  ];

  # Offer windows as well as monitors in the screen-share portal (upstream asks
  # for monitors only).
  postPatch = ''
    substituteInPlace internal/airplay/capture.go \
      --replace-fail '"types":        dbus.MakeVariant(uint32(1)), // MONITOR=1, WINDOW=2' \
                     '"types":        dbus.MakeVariant(uint32(3)), // MONITOR=1, WINDOW=2'
  '';

  # Tests spin up receivers and probe GStreamer.
  doCheck = false;

  postInstall = ''
    installManPage man/man1/*.1
  '';

  postFixup = ''
    wrapProgram $out/bin/doubletake \
      --prefix PATH : ${lib.makeBinPath (map lib.getBin runtimeTools)} \
      --prefix GST_PLUGIN_SYSTEM_PATH_1_0 : ${lib.makeSearchPathOutput "lib" "lib/gstreamer-1.0" gstPlugins}
  '';

  meta = {
    description = "AirPlay screen mirroring sender for Linux";
    homepage = "https://github.com/omarroth/doubletake";
    license = lib.licenses.lgpl3Plus;
    mainProgram = "doubletake";
    platforms = lib.platforms.linux;
  };
})
