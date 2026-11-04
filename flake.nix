rec {
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel";
    nixos-hardware = {
      url = "github:NixOS/nixos-hardware";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    devenv = {
      url = "github:cachix/devenv";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    lanzaboote = {
      url = "github:nix-community/lanzaboote/v0.4.2";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    asus-dialpad-driver = {
      url = "github:asus-linux-drivers/asus-dialpad-driver";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    mangowm = {
      url = "github:mangowm/mango";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    vscode-extensions = {
      url = "github:nix-community/nix-vscode-extensions";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-gaming = {
      url = "github:fufexan/nix-gaming";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    dank-material-shell = {
      url = "github:AvengeMedia/DankMaterialShell";
      inputs.nixpkgs.follows = "nixpkgs";
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
    microvm = {
      url = "github:microvm-nix/microvm.nix";
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
      "flox-cache-public-1:7F4OyH7ZCnFhcze3fJdfyXYLQw/aV7GEed86nQ7IsOs= "
      "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
      "nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svXaZF/Ees8vCUUs4="
    ];
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      home-manager,
      devenv,
      mangowm,
      vscode-extensions,
      giantswarm,
      ...
    }@inputs:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
          config.cudaSupport = nixpkgs.lib.hasSuffix "-linux" system; # no CUDA on macOS
          # Adding an overlay to allow access to all packages through nixpkgs
          overlays = [
            giantswarm.overlay
            vscode-extensions.overlays.default
            mangowm.overlays.default
            self.overlays.default
          ];
        };

        # packagesFromDirectoryRecursive includes functions like callPackage
        localPackages = nixpkgs.lib.packagesFromDirectoryRecursive {
          inherit (pkgs) callPackage newScope;
          directory = ./pkgs;
        };
      in
      {
        # Only direct derivations should be exposed through 'packages'
        packages = nixpkgs.lib.filterAttrs (_: pkg: nixpkgs.lib.isDerivation pkg) localPackages;

        legacyPackages = localPackages // {
          # Standalone home-manager configuration entrypoint
          # Available through 'home-manager switch --flake .#username'
          homeConfigurations = nixpkgs.lib.genAttrs (self.lib.listNixModules ./users) (
            username:
            home-manager.lib.homeManagerConfiguration {
              inherit pkgs; # Home-manager requires 'pkgs' instance
              extraSpecialArgs = {
                inherit self inputs username;
              };
              modules = [
                self.homeManagerModules.default
                ./users/${username}
              ];
            }
          );
        };

        devShells.default = devenv.lib.mkShell {
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
              name = "dotfiles";

              # https://devenv.sh/reference/options/
              # packages = with pkgs; [ ];
            }
          ];
        };
      }
    )
    // {
      # NixOS configuration entrypoint
      # Available through 'nixos-rebuild switch --flake .#hostname'
      nixosConfigurations = nixpkgs.lib.genAttrs (self.lib.listNixModules ./hosts) (
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
            ./hosts/${hostname}
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
