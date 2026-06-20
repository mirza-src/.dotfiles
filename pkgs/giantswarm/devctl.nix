{
  git,
  fetchgit, # HACK: leaveDotGit appears to be work only with this fetcher
  buildGoModule,
  ...
}:
buildGoModule (finalAttrs: {
  pname = "devctl";
  version = "8.20.3";

  src = fetchgit {
    url = "https://github.com/giantswarm/${finalAttrs.pname}";
    rev = "v${finalAttrs.version}";
    sha256 = "sha256-z6WJUf5Ax54XwrKOlnIZjve447QybjpJzDzyKHy8WqE=";
    leaveDotGit = true; # Generate script uses git history
  };

  nativeBuildInputs = [ git ];
  preBuild = ''
    go generate ./...
  '';

  proxyVendor = true;
  vendorHash = "sha256-ERfHZDahLjMaA26uB/ZOdGaJCLGt/NFyBzuxftyj9Ow=";
})
