{
  fetchFromGitHub,
  buildGoModule,
  ...
}:
buildGoModule (finalAttrs: {
  pname = "gg";
  version = "0.1.0";

  src = fetchFromGitHub {
    owner = "giantswarm";
    repo = finalAttrs.pname;
    rev = "v${finalAttrs.version}";
    hash = "sha256-G6EsPJ791LxnD8w51d5eR9P4zhpXU+hrSvl7M0PYFyc=";
  };

  vendorHash = "sha256-YylMnEu1zaOt0dD2pf6o8ioSY9TMUwsVsQELp11Km3w=";
})
