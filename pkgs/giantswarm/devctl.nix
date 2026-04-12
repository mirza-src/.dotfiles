{
  git,
  fetchgit, # HACK: leaveDotGit appears to be work only with this fetcher
  buildGoModule,
  ...
}:
buildGoModule (finalAttrs: {
  pname = "devctl";
  version = "7.33.1";

  src = fetchgit {
    url = "https://github.com/giantswarm/${finalAttrs.pname}";
    rev = "v${finalAttrs.version}";
    sha256 = "sha256-/ZScmytBiM2j7l7Nbsp+N+G8muZRexCDpVDcH90aU5I=";
    leaveDotGit = true; # Generate script uses git history
  };

  nativeBuildInputs = [ git ];
  preBuild = ''
    go generate ./...
  '';

  proxyVendor = true;
  vendorHash = "sha256-B+6UmIzFJTGQaawZNnUY3EOvzuaWc6BuSHvcx+saAvE=";
})
