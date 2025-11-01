{
  fetchFromGitHub,
  buildGoModule,
  ...
}:
buildGoModule (finalAttrs: {
  pname = "helm-tool";
  version = "0.5.3";

  src = fetchFromGitHub {
    owner = "cert-manager";
    repo = finalAttrs.pname;
    rev = "v${finalAttrs.version}";
    hash = "sha256-rmy4x4NUzE8eQ6RDY191ROdCGVg2kNQ5Ay3qN4BV0NU=";
  };

  vendorHash = "sha256-SOgW+5OhiAfM1IY+IH5pE7WORIsvl2co2sMe07Hjees=";
})
