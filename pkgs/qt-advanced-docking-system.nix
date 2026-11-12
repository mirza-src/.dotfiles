{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  qt6,
  libxcb,
  ...
}:
# Not nixpkgs' `qtads`, which is an unrelated TADS interpreter.
stdenv.mkDerivation (finalAttrs: {
  pname = "qt-advanced-docking-system";
  version = "5.1.1";

  src = fetchFromGitHub {
    owner = "githubuser0xFFFF";
    repo = "Qt-Advanced-Docking-System";
    tag = "v${finalAttrs.version}";
    hash = "sha256-W5QoovaSRQdfx7U75cdWqfP8zE/VWqAh9eURrtuvLys=";
  };

  nativeBuildInputs = [ cmake ];
  buildInputs = [ qt6.qtbase ];
  # The exported target links `xcb` publicly, by bare name.
  propagatedBuildInputs = lib.optionals stdenv.hostPlatform.isLinux [ libxcb ];
  dontWrapQtApps = true;

  cmakeFlags = [
    (lib.cmakeBool "BUILD_EXAMPLES" false)
    (lib.cmakeFeature "QT_VERSION_MAJOR" "6")
  ];

  meta = {
    description = "Advanced docking system for Qt, like Visual Studio's";
    homepage = "https://github.com/githubuser0xFFFF/Qt-Advanced-Docking-System";
    changelog = "https://github.com/githubuser0xFFFF/Qt-Advanced-Docking-System/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.lgpl21Plus;
    platforms = lib.platforms.unix;
  };
})
