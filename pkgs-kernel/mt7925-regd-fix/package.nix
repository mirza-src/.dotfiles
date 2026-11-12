# mt76 (only what mt7925e needs) from the running kernel, with the MT7925's
# self-managed regulatory domain turned off. Since 7.3 (mt76 commit
# e9f3f1cc13, "mt7925: add regulatory wiphy self manager support") the
# firmware drops frames injected through a monitor interface, which breaks
# AirDrop over AWDL (omdrop-owl): the Mac never sees this machine. Ordinary
# Wi-Fi is unaffected. Modules land in updates/ and override the stock ones.
# Found by bisecting v7.2..v7.3.1; drop once upstream fixes it.
{
  stdenv,
  kernel,
  kernelModuleMakeFlags,
}:
let
  dir = "drivers/net/wireless/mediatek/mt76";
in
stdenv.mkDerivation {
  pname = "mt7925-regd-fix";
  inherit (kernel) version src;
  patches = [ ./no-self-managed-regd.patch ];

  hardeningDisable = [ "pic" ];
  nativeBuildInputs = kernel.moduleBuildDependencies;
  makeFlags = kernelModuleMakeFlags ++ [
    "-C"
    "${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
    "INSTALL_MOD_PATH=${placeholder "out"}"
    "INSTALL_MOD_DIR=updates"
    # Only mt76 core, the connac/mt792x libraries and mt7925e, so they all
    # come from the same source. The rest stay the stock modules.
    "CONFIG_MT76_USB="
    "CONFIG_MT76_SDIO="
    "CONFIG_MT76x02_LIB="
    "CONFIG_MT76x02_USB="
    "CONFIG_MT792x_USB="
    "CONFIG_MT76x0_COMMON="
    "CONFIG_MT76x2_COMMON="
    "CONFIG_MT7603E="
    "CONFIG_MT7615_COMMON="
    "CONFIG_MT7915E="
    "CONFIG_MT7921_COMMON="
    "CONFIG_MT7996E="
    "CONFIG_MT7925U="
  ];

  # kernel.src is a tree for CachyOS and a tarball for mainline.
  unpackPhase = ''
    if [ -d "$src" ]; then
      mkdir -p ${dir}
      cp -r "$src/${dir}/." ${dir}/
    else
      tar -xf "$src" --strip-components=1 --wildcards '*/${dir}/*'
    fi
    chmod -R u+w drivers
  '';

  buildPhase = ''
    runHook preBuild
    cd ${dir}
    make $makeFlags M=$PWD modules
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    make $makeFlags M=$PWD modules_install
    runHook postInstall
  '';

  # Built from the kernel's own source; nothing to update.
  passthru.skipUpdate = true;
}
