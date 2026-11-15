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
      (lib.filterAttrs (
        name: type: !lib.hasPrefix "." name && (type == "directory" || lib.hasSuffix ".nix" name)
      ))
      (lib.mapAttrsToList (name: _: lib.removeSuffix ".nix" name))
    ];

  # Toolsets: sets of tools switched on from anywhere with `tools`
  # (modules/home-manager/toolsets). Each ../toolsets/<name>.nix (or
  # <name>/default.nix) is `{ pkgs, lib }: { description; packages; env; }`;
  # env values are written in double quotes, so $HOME etc. expand.
  toolsetNames = if builtins.pathExists ../toolsets then listNixModules ../toolsets else [ ];

  loadToolsets =
    pkgs:
    lib.genAttrs toolsetNames (
      name:
      let
        file = ../toolsets + "/${name}.nix";
        def = import (if builtins.pathExists file then file else ../toolsets + "/${name}") {
          inherit pkgs lib;
        };
        unknown = lib.attrNames (
          removeAttrs def [
            "description"
            "packages"
            "env"
          ]
        );
      in
      lib.throwIf (unknown != [ ]) "toolsets/${name}: unknown attributes ${toString unknown}" (
        {
          description = "";
          packages = [ ];
          env = { };
        }
        // def
      )
    );

  toolsetInfo = pkgs: lib.mapAttrs (_: t: t.description) (loadToolsets pkgs);

  # A buildEnv for every combination of toolsets, named by its members
  # sorted and joined with "+" ("none" for the empty one). Only the one asked
  # for is evaluated. Besides the packages it holds etc/tools/{names,vars,env.sh}
  # for the `tools` command and the shell hook.
  mkToolsets =
    pkgs:
    let
      defs = loadToolsets pkgs;
      build =
        names:
        let
          key = if names == [ ] then "none" else lib.concatStringsSep "+" names;
          env = lib.foldl' (
            acc: name:
            lib.foldlAttrs (
              vars: var: value:
              let
                v = toString value;
              in
              lib.throwIf (
                vars ? ${var} && vars.${var} != v
              ) "toolsets ${key}: ${name} sets ${var} differently than another toolset" (vars // { ${var} = v; })
            ) acc defs.${name}.env
          ) { } names;
        in
        lib.nameValuePair key (
          pkgs.buildEnv {
            name = "toolset-${key}";
            paths = lib.concatMap (name: defs.${name}.packages) names ++ [
              (pkgs.writeTextDir "etc/tools/names" (lib.concatLines names))
              (pkgs.writeTextDir "etc/tools/vars" (lib.concatLines (lib.attrNames env)))
              (pkgs.writeTextDir "etc/tools/env.sh" (
                lib.concatLines (lib.mapAttrsToList (var: v: ''export ${var}="${v}"'') env)
              ))
            ];
          }
        );
      # All subsets, each in the (sorted) order of toolsetNames.
      subsets = lib.foldr (x: acc: acc ++ map (s: [ x ] ++ s) acc) [ [ ] ] toolsetNames;
    in
    lib.listToAttrs (map build subsets);

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
    modules
    // {
      default =
        { ... }:
        {
          imports = lib.attrValues fileModules ++ lib.mapAttrsToList (_: ns: ns.default) dirModules;
        };
    };
}
