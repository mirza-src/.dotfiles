{
  fetchFromGitHub,
  buildGoModule,
  ...
}:
buildGoModule (finalAttrs: {
  pname = "helm-schema-gen";
  version = "0.0.4";

  src = fetchFromGitHub {
    owner = "karuppiah7890";
    repo = finalAttrs.pname;
    rev = finalAttrs.version;
    hash = "sha256-B6Ypdnvrysk3stkJ4NinNfOqXy/u7vEuaHpY5SY+Dgk=";
  };

  vendorHash = "sha256-P+gJdpmbMll9NxpUlQGQ/3so1P0khEFdsQKOQOHD0dw=";
})
