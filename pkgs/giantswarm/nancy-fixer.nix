{
  fetchFromGitHub,
  buildGoModule,
  ...
}:
buildGoModule (finalAttrs: {
  pname = "nancy-fixer";
  version = "0.12.2";

  src = fetchFromGitHub {
    owner = "giantswarm";
    repo = finalAttrs.pname;
    rev = "v${finalAttrs.version}";
    hash = "sha256-QEcQW1PRhNyD+BE0PZBTYcsSjkTNJsZTou6Povn94UU=";
  };

  vendorHash = "sha256-FMNTbqdOl5UssPJERKyi0b2gCgGPAK98P5sjJpkS7ow=";
})
