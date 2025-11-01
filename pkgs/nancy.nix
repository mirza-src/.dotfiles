{
  fetchFromGitHub,
  buildGoModule,
  ...
}:
buildGoModule (finalAttrs: {
  pname = "nancy";
  version = "1.0.52";

  src = fetchFromGitHub {
    owner = "sonatype-nexus-community";
    repo = finalAttrs.pname;
    rev = "v${finalAttrs.version}";
    hash = "sha256-FKjx6Sis2dQdLSz35bVCVm+6cppS7i3szCfLfmEZoJA=";
  };

  vendorHash = "sha256-FI5hRSXExF6ckmj658BEYR+jsMRLypdNrViU9bnVhBw=";

  # TODO: Some tests failing in sandboxed environment
  doCheck = false;
})
