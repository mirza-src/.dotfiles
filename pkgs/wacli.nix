{
  lib,
  buildGo127Module,
  fetchFromGitHub,
  ...
}:
buildGo127Module (finalAttrs: {
  pname = "wacli";
  version = "0.19.0";

  src = fetchFromGitHub {
    owner = "openclaw";
    repo = "wacli";
    tag = "v${finalAttrs.version}";
    hash = "sha256-DXLKNujdE24hfIK+bkhDyBlmyGSineO3D73hILJhizc=";
  };

  vendorHash = "sha256-gqX3Db8bmJVzos/vGR0ekS0520HvabFb2IYJmq1TMNI=";

  subPackages = [ "cmd/wacli" ];

  # Matches upstream's .goreleaser-linux-windows.yaml: CGO (mattn/go-sqlite3)
  # with FTS5 enabled.
  env.CGO_ENABLED = 1;
  env.CGO_CFLAGS = "-Wno-error=missing-braces";
  tags = [ "sqlite_fts5" ];

  ldflags = [
    "-s"
    "-w"
    "-X main.version=${finalAttrs.version}"
    "-X main.releaseLinkerSetting=wacli-release-linker-version=[${finalAttrs.version}]"
  ];

  # Tests need network / a WhatsApp session.
  doCheck = false;

  meta = {
    description = "WhatsApp CLI: sync, search, send";
    homepage = "https://github.com/openclaw/wacli";
    license = lib.licenses.mit;
    mainProgram = "wacli";
    platforms = lib.platforms.linux;
  };
})
