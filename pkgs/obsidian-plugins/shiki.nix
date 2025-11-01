{
  fetchzip,
  stdenv,
  ...
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "obsidian-shiki-plugin";
  version = "0.7.0";
  phases = [
    "installPhase"
    "fixupPhase"
  ];

  src = fetchzip {
    url = "https://github.com/mProjectsCode/${finalAttrs.pname}/releases/download/${finalAttrs.version}/shiki-highlighter-${finalAttrs.version}.zip";
    hash = "sha256-qefQc5mHE9YmQZ+M+PldO1Jub9l8hhR9cYepoMr00rs=";
  };

  installPhase = ''
    mkdir -p $out
    cp -r $src/* $out/
  '';
})
