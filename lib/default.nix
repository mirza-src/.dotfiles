{ lib, ... }:
rec {
  # Allows every unfree package, like `allowUnfree = true` (which must stay
  # unset, or nixpkgs never calls this). With TRACE_UNFREE=1 (needs --impure)
  # it also names, on stderr, each one whose license forbids redistributing
  # it, so cachix-sync can keep them out of the public binary cache.
  # Redistributable ones (unfreeRedistributable: NVIDIA's driver, Steam, ...)
  # may be cached.
  allowUnfreePredicate =
    if builtins.getEnv "TRACE_UNFREE" == "1" then
      pkg:
      let
        licenses = lib.toList (pkg.meta.license or [ ]);
        redistributable = licenses != [ ] && lib.all (l: l.redistributable or false) licenses;
      in
      if redistributable then
        true
      else
        builtins.trace "unfree: ${pkg.name or "${pkg.pname}-${pkg.version}"}" true
    else
      _: true;

  # Flatten nested package sets into one level of derivations, joining the
  # names with "-": { a = drv; b.c = drv; } -> { a = drv; b-c = drv; }
  flattenPackages =
    let
      go =
        prefix:
        lib.concatMapAttrs (
          name: value:
          let
            path = if prefix == null then name else "${prefix}-${name}";
          in
          if lib.isDerivation value then
            { ${path} = value; }
          else if lib.isAttrs value then
            go path value
          else
            { }
        );
    in
    go null;

  listNixModules =
    dir:
    lib.pipe (builtins.readDir dir) [
      (lib.filterAttrs (name: type: !lib.hasPrefix "." name && (type == "directory" || lib.hasSuffix ".nix" name)))
      (lib.mapAttrsToList (name: _: lib.removeSuffix ".nix" name))
    ];

  createModuleEntryPoint =
    dir:
    let
      entries = lib.filterAttrs (name: _: !lib.hasPrefix "." name && name != "default.nix") (
        builtins.readDir dir
      );

      fileModules = lib.pipe entries [
        (lib.filterAttrs (name: type: type == "regular" && lib.hasSuffix ".nix" name))
        (lib.mapAttrs' (name: _: lib.nameValuePair (lib.removeSuffix ".nix" name) (dir + "/${name}")))
      ];

      dirModules = lib.pipe entries [
        (lib.filterAttrs (_: type: type == "directory"))
        (lib.mapAttrs (name: _: createModuleEntryPoint (dir + "/${name}")))
      ];

      modules = fileModules // dirModules;
    in
    modules // {
      default =
        { ... }:
        {
          imports =
            lib.attrValues fileModules
            ++ lib.mapAttrsToList (_: ns: ns.default) dirModules;
        };
    };
}
