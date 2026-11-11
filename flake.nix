rec {
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    devenv = {
      url = "github:cachix/devenv";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    cachyos-kernel = {
      # Deliberately keeps its own nixpkgs, so its kernels hit cache.lantian.pub
      url = "github:xddxdd/nix-cachyos-kernel/release";
      inputs.flake-parts.follows = "devenv/flake-parts";
      inputs.flake-compat.follows = "devenv/flake-compat";
    };
    nixos-hardware = {
      url = "github:NixOS/nixos-hardware";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    lanzaboote = {
      url = "github:nix-community/lanzaboote/v1.2.0";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.pre-commit.follows = "devenv/git-hooks";
    };
    mangowm = {
      url = "github:mangowm/mango";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "devenv/flake-parts";
    };
    vscode-extensions = {
      url = "github:nix-community/nix-vscode-extensions";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-gaming = {
      url = "github:fufexan/nix-gaming";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "devenv/flake-parts";
      inputs.flake-compat.follows = "devenv/flake-compat";
      inputs.git-hooks.follows = "devenv/git-hooks";
    };
    dank-material-shell = {
      url = "github:AvengeMedia/DankMaterialShell";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-compat.follows = "devenv/flake-compat";
    };
    dank-greeter = {
      url = "github:AvengeMedia/dank-greeter";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    danksearch = {
      url = "github:AvengeMedia/danksearch";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    dms-plugin-registry = {
      url = "github:AvengeMedia/dms-plugin-registry";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    gaze = {
      url = "github:GunduLabs/gaze";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    giantswarm = {
      url = "github:giantswarm/nix-gs";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # HACK: To allow pure evaluation
    devenv-root = {
      url = "file+file:///dev/null";
      flake = false;
    };
  };

  nixConfig = {
    extra-substituters = [
      "https://cache.lantian.pub/lantian"
      "https://nix-community.cachix.org"
      "https://cache.nixos-cuda.org"
      "https://cache.flox.dev"
      "https://devenv.cachix.org"
      "https://nix-gaming.cachix.org"
    ];
    extra-trusted-public-keys = [
      "lantian:WVGO7vsRMSEN+h7Lp7kv6SAmrkEXgUGbbXm7jMDjBuQ="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="
      "flox-cache-public-1:7F4OyH7ZCnFhcze3fJdfyXYLQw/aV7GEed86nQ7IsOs="
      "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
      "nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svXaZF/Ees8vCUUs4="
    ];
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      devenv,
      ...
    }@inputs:
    let
      inherit (nixpkgs) lib;

      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];
      forAllSystems = lib.genAttrs systems;

      # Only for building this flake's own packages (some are unfree); NixOS
      # and home-manager configure their own nixpkgs in modules.
      pkgsFor = forAllSystems (
        system:
        import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        }
      );

      # packagesFromDirectoryRecursive includes functions like callPackage
      # Local packages, nested as in the directory tree
      localPackagesFor = forAllSystems (
        system:
        let
          pkgs = pkgsFor.${system};
        in
        lib.packagesFromDirectoryRecursive {
          inherit (pkgs) callPackage newScope;
          directory = ./pkgs;
        }
        // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
          # Kernel modules from ./pkgs-kernel, under linuxPackages like in
          # nixpkgs. Built against the latest mainline kernel here; hosts
          # build them against their own kernel (see overlay.nix).
          linuxPackages = lib.packagesFromDirectoryRecursive {
            inherit (pkgs.linuxPackages_latest) callPackage;
            directory = ./pkgs-kernel;
          };
        }
      );
    in
    {
      # 'packages' must be flat: nested sets become e.g. giantswarm-gg
      packages = forAllSystems (system: self.lib.flattenPackages localPackagesFor.${system});

      legacyPackages = forAllSystems (
        system:
        localPackagesFor.${system}
        // {
          # Standalone home-manager configuration entrypoint
          # Available through 'home-manager switch --flake .#username'
          homeConfigurations = lib.genAttrs (self.lib.listNixModules ./users) (
            username:
            home-manager.lib.homeManagerConfiguration {
              # One nixpkgs with all overlays and config, so modules don't set
              # nixpkgs.* (which would make home-manager import it again).
              pkgs = import nixpkgs {
                inherit system;
                overlays = lib.attrValues self.overlays ++ [
                  inputs.vscode-extensions.overlays.default
                  inputs.giantswarm.overlay
                ];
                config = {
                  allowUnfree = true;
                  permittedInsecurePackages = [ "electron-39.8.10" ];
                };
              };
              extraSpecialArgs = {
                inherit self inputs username;
              };
              modules = [
                self.homeManagerModules.default
                ./users/${username}
              ];
            }
          );
        }
      );

      # `nix fmt`: nixfmt over the whole tree
      formatter = forAllSystems (system: pkgsFor.${system}.nixfmt-tree);

      # `nix flake check`: lint with statix and deadnix
      checks = forAllSystems (
        system:
        let
          pkgs = pkgsFor.${system};
        in
        {
          lint =
            pkgs.runCommand "lint"
              {
                nativeBuildInputs = [
                  pkgs.statix
                  pkgs.deadnix
                ];
              }
              ''
                cd ${self}
                statix check --config ${./statix.toml} .
                # Lambda args (overlay/callPackage signatures) are often unused on purpose.
                deadnix --fail --no-lambda-arg --exclude hosts/nixos/zephyrus/hardware-configuration.nix .
                touch $out
              '';
        }
      );

      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
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
                  lib.mkIf (devenvRootFileContent != "") devenvRootFileContent;
              }
              {
                name = "dotfiles";

                # https://devenv.sh/reference/options/
                # packages = with pkgs; [ ];
              }
            ];
          };
        }
      );

      # NixOS configuration entrypoint
      # Available through 'nixos-rebuild switch --flake .#hostname'
      nixosConfigurations = nixpkgs.lib.genAttrs (self.lib.listNixModules ./hosts/nixos) (
        hostname:
        nixpkgs.lib.nixosSystem {
          specialArgs = {
            inherit
              self
              inputs
              hostname
              nixConfig
              ;
          };
          modules = [
            self.nixosModules.default
            ./hosts/nixos/${hostname}
          ];
        }
      );

      overlays.default = (import ./overlay.nix) inputs;

      lib = import ./lib {
        inherit self;
        inherit (nixpkgs) lib;
      };

      modules = import ./modules {
        inherit self;
        inherit (nixpkgs) lib;
      };
      nixosModules = self.modules.nixos;
      homeManagerModules = self.modules.home-manager;

      templates =
        nixpkgs.lib.genAttrs (self.lib.listNixModules ./templates) (template: {
          path = ./templates/${template};
          description = "Template for ${template}";
        })
        // {
          default = self.templates.devenv;
        };
    };
}
