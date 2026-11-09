# hid-asus with a settable Fn-lock default (hid_asus.fnlock_default), restored
# on resume, plus a fn_lock sysfs attribute. Only this one module is built
# against the running kernel; it lands in updates/ and so overrides the stock
# hid-asus without rebuilding the kernel.
{
  stdenv,
  kernel,
  kernelModuleMakeFlags,
}:
stdenv.mkDerivation {
  pname = "hid-asus-fnlock";
  inherit (kernel) version src;
  patches = [ ./hid-asus-fnlock.patch ];

  hardeningDisable = [ "pic" ];
  nativeBuildInputs = kernel.moduleBuildDependencies;
  makeFlags = kernelModuleMakeFlags ++ [
    "-C"
    "${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
    "INSTALL_MOD_PATH=${placeholder "out"}"
    "INSTALL_MOD_DIR=updates"
  ];

  # kernel.src is the already-patched source tree; copy just what we need.
  unpackPhase = ''
    mkdir -p drivers/hid
    cp $src/drivers/hid/{hid-asus.c,hid-ids.h} drivers/hid/
    chmod -R u+w drivers
  '';

  buildPhase = ''
    runHook preBuild
    cd drivers/hid
    echo 'obj-m := hid-asus.o' > Kbuild
    make $makeFlags M=$PWD modules
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    make $makeFlags M=$PWD modules_install
    runHook postInstall
  '';
}
