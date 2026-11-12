{
  lib,
  buildGo127Module,
  fetchFromGitHub,
  ...
}:
buildGo127Module (finalAttrs: {
  pname = "wacli";
  version = "0.26.0";

  src = fetchFromGitHub {
    owner = "openclaw";
    repo = "wacli";
    tag = "v${finalAttrs.version}";
    hash = "sha256-CVjttZfkV1kIHxZTmWSJL3h4Zt/+c7A11LIJBrQu8kc=";
  };

  vendorHash = "sha256-PsKqI3zzNw5e38DSfa/qjorfjFsTxTRzNcw/EH4L9rk=";

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
