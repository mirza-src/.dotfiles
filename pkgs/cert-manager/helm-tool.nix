{
  fetchFromGitHub,
  buildGoModule,
  ...
}:
buildGoModule (finalAttrs: {
  pname = "helm-tool";
  version = "0.6.0";

  src = fetchFromGitHub {
    owner = "cert-manager";
    repo = finalAttrs.pname;
    rev = "v${finalAttrs.version}";
    hash = "sha256-E3rj/P/Ms3LKuKTThOnmiGvnwb/8x0a21F4O61aoyIE=";
  };

  vendorHash = "sha256-mjdCfVIA4GOj5DiJfjvu4NJtB7/URQ7jRArEuWoZ4AM=";
})
