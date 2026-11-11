{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    devenv = {
      url = "github:cachix/devenv";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # HACK: To allow pure evaluation
    devenv-root = {
      url = "file+file:///dev/null";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      devenv,
      ...
    }@inputs:
    let
      inherit (nixpkgs) lib;

      forAllSystems = lib.genAttrs [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];

      pkgsFor = forAllSystems (
        system:
        import nixpkgs {
          inherit system;
          config.allowUnfree = true;

          # Adding an overlay to allow access to all packages through nixpkgs
          overlays = [
            self.overlays.default
          ];
        }
      );
    in
    {
      # Add outputs that depend on system here, e.g. devShells, packages, apps, etc.
      devShells = forAllSystems (
        system:
        let
          pkgs = pkgsFor.${system};
        in
        {
          default = devenv.lib.mkShell {
            inherit inputs pkgs;
            modules = [
              {
                # HACK: To allow pure evaluation
                devenv.root =
                  let
                    devenvRootFileContent = builtins.readFile inputs.devenv-root.outPath;
                  in
                  pkgs.lib.mkIf (devenvRootFileContent != "") devenvRootFileContent;
              }
              {
                # https://devenv.sh/reference/options/
                packages = with pkgs; [ git ];
              }
            ];
          };
        }
      );

      # Add outputs that do not depend on system here, e.g. overlays, templates, etc.
      overlays = {
        default = final: prev: {
          # Define custom packages or overrides here
        };
      };
    };
}
