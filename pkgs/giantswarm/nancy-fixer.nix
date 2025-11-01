{
  fetchFromGitHub,
  buildGoModule,
  ...
}:
buildGoModule (finalAttrs: {
  pname = "nancy-fixer";
  version = "0.6.0";

  src = fetchFromGitHub {
    owner = "giantswarm";
    repo = finalAttrs.pname;
    rev = "v${finalAttrs.version}";
    hash = "sha256-b2MZGbeKTTDLnAwWqAoggZigeGo0hxSvkzwJWf2PIsE=";
  };

  vendorHash = "sha256-FMNTbqdOl5UssPJERKyi0b2gCgGPAK98P5sjJpkS7ow=";
})
