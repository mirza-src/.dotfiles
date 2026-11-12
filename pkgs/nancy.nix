{
  fetchFromGitHub,
  buildGoModule,
  ...
}:
buildGoModule (finalAttrs: {
  pname = "nancy";
  version = "2.1.1";

  src = fetchFromGitHub {
    owner = "sonatype-nexus-community";
    repo = finalAttrs.pname;
    rev = "v${finalAttrs.version}";
    hash = "sha256-+WC+gUDz9Or6Fwroj/+NSFu6nAm5uGW/CvexbDXtJ4o=";
  };

  vendorHash = "sha256-yS8Jn1WbzSxzONJd+PZpYM6nm8chmnJsvSrX7gl3V3w=";

  # TODO: Some tests failing in sandboxed environment
  doCheck = false;
})
