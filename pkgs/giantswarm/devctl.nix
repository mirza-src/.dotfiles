{
  git,
  fetchgit, # HACK: leaveDotGit appears to be work only with this fetcher
  buildGoModule,
  ...
}:
buildGoModule (finalAttrs: {
  pname = "devctl";
  version = "7.20.3";

  src = fetchgit {
    url = "https://github.com/giantswarm/${finalAttrs.pname}";
    rev = "v${finalAttrs.version}";
    sha256 = "sha256-+R7URDq1hL72FjK4bvbbjJC8Z5IFUKPOYCoj0K2powg=";
    leaveDotGit = true; # Generate script uses git history
  };

  nativeBuildInputs = [ git ];
  preBuild = ''
    go generate ./...
  '';

  vendorHash = "sha256-4fjTn7zFKo2RfSPdJqF0Hl37OXlwe2h6XpKSYO5PH8w=";
})
