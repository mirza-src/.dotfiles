{
  fetchzip,
  stdenv,
  ...
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "obsidian-shiki-plugin";
  version = "0.8.0";
  phases = [
    "installPhase"
    "fixupPhase"
  ];

  src = fetchzip {
    url = "https://github.com/mProjectsCode/${finalAttrs.pname}/releases/download/${finalAttrs.version}/shiki-highlighter-${finalAttrs.version}.zip";
    hash = "sha256-s8qBMMGeA9cwlY4DNoGmoGIY6M6YZgnoa2Mwin458Q0=";
  };

  installPhase = ''
    mkdir -p $out
    cp -r $src/* $out/
  '';
})
