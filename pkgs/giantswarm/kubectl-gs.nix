{
  fetchFromGitHub,
  buildGoModule,
  ...
}:
buildGoModule (finalAttrs: {
  pname = "kubectl-gs";
  version = "5.3.1";

  src = fetchFromGitHub {
    owner = "giantswarm";
    repo = finalAttrs.pname;
    rev = "v${finalAttrs.version}";
    hash = "sha256-Wu9ybRA3Iusl+sOGdrCgJhmIppUAlw9ipWQ67Zn46Jc=";
  };

  vendorHash = "sha256-ksmGQe914+zacYgFWnxTCBRpM8nG2GGRW1tXJrxsyjE=";

  # TODO: Some tests failing in sandboxed environment
  doCheck = false;
})
