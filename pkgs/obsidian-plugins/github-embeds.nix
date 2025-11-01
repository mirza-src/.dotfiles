{
  buildNpmPackage,
  fetchFromGitHub,
  ...
}:
buildNpmPackage (finalAttrs: {
  pname = "obsidian-github-embeds";
  version = "1.0.7";

  src = fetchFromGitHub {
    owner = "MrGVSV";
    repo = finalAttrs.pname;
    tag = finalAttrs.version;
    hash = "sha256-Z0SCw22EJI6zcqkxI/QeSZ17qn98iA5vwlakW5/qT6U=";
  };

  installPhase = ''
    mkdir -p $out
    cp ./{main.js,manifest.json,styles.css} $out/
  '';

  npmDepsHash = "sha256-9faMOK8mwF1IoiziTxzX1DwgtEBUWbwMOkNeb0Srki4=";
})
