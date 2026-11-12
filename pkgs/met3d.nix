{
  lib,
  stdenv,
  fetchFromGitLab,
  fetchzip,
  cmake,
  ninja,
  pkg-config,
  icoutils,
  copyDesktopItems,
  makeDesktopItem,
  qt6,
  glfx,
  qt-advanced-docking-system,
  tinygltf_2,
  log4cplus,
  gdal,
  gsl,
  eccodes,
  netcdf,
  netcdfcxx4,
  proj,
  libzip,
  python3,
  freefont_ttf,

  # Data upstream's third-party/CMakeLists.txt downloads at configure time.
  # Override with `met3d.override { <name> = ...; }`; each must be a directory
  # laid out like the extracted zip.
  naturalEarthCoastlines ? fetchzip {
    url = "https://naciscdn.org/naturalearth/50m/physical/ne_50m_coastline.zip";
    stripRoot = false;
    hash = "sha256-qmkcUiANOAnU8bq7wzc43l/3szxwEK39qiNOTWxZ824=";
  },
  naturalEarthBorders ? fetchzip {
    url = "https://naciscdn.org/naturalearth/50m/cultural/ne_50m_admin_0_boundary_lines_land.zip";
    stripRoot = false;
    hash = "sha256-et2RAo3tjR8IAviQ5GSxQ07yN+ARi4zFzBXkKDQ3748=";
  },
  naturalEarthBasemap ? fetchzip {
    url = "https://naciscdn.org/naturalearth/50m/raster/HYP_50M_SR_W.zip";
    stripRoot = false;
    hash = "sha256-6jll1pKY9KQ2q4WIiNDRndMzWELc2VJKdvb/VmWcUu8=";
  },
  scientificColourMaps ? fetchzip {
    url = "https://zenodo.org/record/5501399/files/ScientificColourMaps7.zip";
    hash = "sha256-NSDVM3GZRobhIY38Q5qPH5keGoQTk+tbn2xorPnqqCo=";
  },
  ...
}:
let
  # netcdf (autotools) ships no CMake package and netcdf-cxx4 4.3.1 only a
  # ConfigVersion file, so define the targets Met.3D links against here.
  netcdfTargets = ''
    add_library(netCDF::netcdf SHARED IMPORTED)
    set_target_properties(netCDF::netcdf PROPERTIES
        IMPORTED_LOCATION "${lib.getLib netcdf}/lib/libnetcdf.so"
        INTERFACE_INCLUDE_DIRECTORIES "${lib.getDev netcdf}/include")
    add_library(netCDF::netcdf-cxx4 SHARED IMPORTED)
    set_target_properties(netCDF::netcdf-cxx4 PROPERTIES
        IMPORTED_LOCATION "${lib.getLib netcdfcxx4}/lib/libnetcdf-cxx4.so"
        INTERFACE_INCLUDE_DIRECTORIES "${lib.getDev netcdfcxx4}/include"
        INTERFACE_LINK_LIBRARIES netCDF::netcdf)
    set(netCDFCxx_VERSION_MAJOR ${lib.versions.major netcdfcxx4.version})
    set(netCDFCxx_VERSION_MINOR ${lib.versions.minor netcdfcxx4.version})
    set(netCDFCxx_VERSION_PATCH ${lib.versions.patch netcdfcxx4.version})
  '';
in
stdenv.mkDerivation (finalAttrs: {
  pname = "met3d";
  version = "2.0.0b11";

  src = fetchFromGitLab {
    owner = "wxmetvis";
    repo = "met.3d";
    tag = finalAttrs.version;
    hash = "sha256-pKM21DdHfaak+mD/EmK9K2a728N2bm2h0eIel5Z6DI8=";
  };

  postPatch = ''
    cat > cmake/nix-netcdf.cmake <<'EOF'
    ${netcdfTargets}
    EOF
    substituteInPlace CMakeLists.txt \
      --replace-fail \
        'find_package(netCDFCxx CONFIG REQUIRED NAMES netCDF netCDFCxx CONFIGS netCDFCxxConfig.cmake)' \
        'include(cmake/nix-netcdf.cmake)' \
      --replace-fail 'add_subdirectory(third-party)' ""
  '';

  nativeBuildInputs = [
    cmake
    ninja
    pkg-config
    icoutils
    copyDesktopItems
    qt6.wrapQtAppsHook
  ];

  buildInputs = [
    qt6.qtbase
    qt6.qtcharts
    qt6.qtsvg
    qt6.qtmultimedia
    qt6.qtimageformats
    qt6.qtwayland
    glfx
    qt-advanced-docking-system
    tinygltf_2
    log4cplus
    gdal
    gsl
    eccodes
    netcdf
    netcdfcxx4
    proj
    libzip
    python3
    python3.pkgs.pybind11
  ];

  # Upstream only has install rules for Windows. On Linux, Met.3D looks for its
  # shaders, configs and data in <prefix>/share/met3d (src/main.cpp).
  installPhase = ''
    runHook preInstall

    install -Dm755 Met3D -t $out/bin
    # The docs (and upstream's Linux builds) call it `met3d`.
    ln -s Met3D $out/bin/met3d

    data=$out/share/met3d
    mkdir -p $data/src $data/third-party/naturalearth $data/third-party/eccodes
    cp -r ../src/glsl $data/src/
    cp -r ../config ../resources ../templates $data/

    ln -s ${freefont_ttf}/share/fonts/truetype $data/third-party/freefont-20120503
    ln -s ${scientificColourMaps} $data/third-party/ScientificColourMaps7
    ln -s ${eccodes}/share/eccodes/definitions $data/third-party/eccodes/definitions
    for d in ${naturalEarthCoastlines} ${naturalEarthBorders} ${naturalEarthBasemap}; do
      ln -s $d/* $data/third-party/naturalearth/
    done

    icotool -x -o icons ../resources/icons/met3d.ico
    install -Dm644 "$(ls -S icons/*.png | head -1)" $out/share/pixmaps/met3d.png

    runHook postInstall
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "met3d";
      desktopName = "Met.3D";
      comment = finalAttrs.meta.description;
      exec = "Met3D";
      icon = "met3d";
      categories = [
        "Science"
        "Education"
        "DataVisualization"
      ];
    })
  ];

  passthru = {
    inherit
      naturalEarthCoastlines
      naturalEarthBorders
      naturalEarthBasemap
      scientificColourMaps
      ;
  };

  meta = {
    description = "Interactive 3D visualization of numerical ensemble weather predictions";
    homepage = "https://met3d.wavestoweather.de";
    changelog = "https://gitlab.com/wxmetvis/met.3d/-/releases/${finalAttrs.version}";
    license = lib.licenses.gpl3Plus;
    mainProgram = "Met3D";
    platforms = lib.platforms.linux;
  };
})
