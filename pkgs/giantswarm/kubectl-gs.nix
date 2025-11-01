{
  fetchFromGitHub,
  buildGoModule,
  ...
}:
buildGoModule (finalAttrs: {
  pname = "kubectl-gs";
  version = "4.8.1";

  src = fetchFromGitHub {
    owner = "giantswarm";
    repo = finalAttrs.pname;
    rev = "v${finalAttrs.version}";
    hash = "sha256-YtlqmM6dSKI3QIW7cE0wwoDY1L5ciNqyHUwpoUFJgJQ=";
  };

  vendorHash = "sha256-OY8Khe9nCLukpLluZXCuTPdynUc3bN9ig5Zm9qJ9tfk=";

  # TODO: Some tests failing in sandboxed environment
  doCheck = false;
})
