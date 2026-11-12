{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  qt6,
  ...
}:
# Met.3D's Qt 6 fork of GLFX (the effect-file parser behind its shaders). The
# commit is the one pinned by Met.3D's vcpkg overlay
# (vcpkg-overlays/glfx/portfile.cmake).
stdenv.mkDerivation {
  pname = "glfx";
  version = "0.7.5-unstable-2026-03-31";

  src = fetchFromGitHub {
    owner = "thorwin-vogt";
    repo = "glfx";
    rev = "e2429bd7c2b8e60c2c3e8a6d7382c45116d38dd4";
    hash = "sha256-s+Qm3u5uiuXuDU+kqOy+PLnMQJPBHB+OA9oGWEoB9Ts=";
  };

  nativeBuildInputs = [ cmake ];
  buildInputs = [ qt6.qtbase ];
  dontWrapQtApps = true;

  meta = {
    description = "OpenGL effect-file library (Met.3D fork)";
    homepage = "https://github.com/thorwin-vogt/glfx";
    license = lib.licenses.bsd2;
    platforms = lib.platforms.unix;
  };
}
