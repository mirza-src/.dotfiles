{
  buildGoModule,
  ...
}:
buildGoModule (finalAttrs: {
  pname = "opsctl";
  version = "7.2.2";

  # Private repo, builtins.fetchGit uses local credentials (fetchFromGitHub does not)
  src = builtins.fetchGit {
    url = "git@github.com:giantswarm/${finalAttrs.pname}";
    ref = "v${finalAttrs.version}";
    rev = "454a90f7ca4cebb75bc61bada35773b92c1e6a64";
  };

  vendorHash = "sha256-fd5IXEjG+ypDvu0eLG8LHPvujfqZ48o++gImyAcbjIY=";
})
