{
  fetchFromGitHub,
  buildGoModule,
  ...
}:
buildGoModule (finalAttrs: {
  pname = "luigi";
  version = "0.1.2";

  src = fetchFromGitHub {
    owner = "giantswarm";
    repo = finalAttrs.pname;
    rev = "v${finalAttrs.version}";
    hash = "sha256-88YsXJ1B1Da7FVt3woPZodq2rA4sVDAFtp+jBEZG6J0=";
  };

  vendorHash = "sha256-ReT7R2LH/ErAD+z2ijJRtUVUXPdl01ZEtnbyBIlDaD0=";
})
