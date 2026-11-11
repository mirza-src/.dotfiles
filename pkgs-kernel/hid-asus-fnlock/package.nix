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

  # kernel.src is a source tree for some kernels (e.g. CachyOS, already
  # patched) and a tarball for others (mainline); extract just what we need.
  unpackPhase = ''
    files="drivers/hid/hid-asus.c drivers/hid/hid-ids.h"
    if [ -d "$src" ]; then
      mkdir -p drivers/hid
      for f in $files; do cp "$src/$f" drivers/hid/; done
    else
      tar -xf "$src" --strip-components=1 --wildcards $(printf '*/%s ' $files)
    fi
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
