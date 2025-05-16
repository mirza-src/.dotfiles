{
  description = "Configuration for MacOS and NixOS";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-utils.url = "github:numtide/flake-utils";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    darwin = {
      url = "github:LnL7/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-homebrew = {
      url = "github:zhaofengli-wip/nix-homebrew";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    homebrew-bundle = {
      url = "github:homebrew/homebrew-bundle";
      flake = false;
    };
    homebrew-core = {
      url = "github:homebrew/homebrew-core";
      flake = false;
    };
    homebrew-cask = {
      url = "github:homebrew/homebrew-cask";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, flake-utils, flake-parts, home-manager, disko, darwin, nix-homebrew, homebrew-bundle, homebrew-core, homebrew-cask } @inputs:
    let
      user = "%USER%";
    in
    flake-parts.lib.mkFlake {inherit inputs;}
    {
      imports = [
        flake-parts.flakeModules.easyOverlay
      ];
      systems = flake-utils.lib.defaultSystems;

      perSystem = { config, system, pkgs, ... }: {
        devShells = {
          default = with pkgs; mkShell {
            nativeBuildInputs = [ bashInteractive git ];
            shellHook = ''
              export EDITOR=vim
            '';
          };
        };
      };

      flake = {
        nixosConfigurations = {
          hostname = nixpkgs.lib.nixosSystem {
            specialArgs = {inherit inputs outputs;};
            modules = [
              disko.nixosModules.disko
              home-manager.nixosModules.home-manager {
                home-manager = {
                  useGlobalPkgs = true;
                  useUserPackages = true;
                  users.${user} = import ./modules/nixos/home-manager.nix;
                };
              }
              ./hosts/nixos
            ];
          };
        };

        darwinConfigurations = {
          hostname = darwin.lib.darwinSystem {
            specialArgs = {inherit inputs outputs;};
            modules = [
              home-manager.darwinModules.home-manager
              nix-homebrew.darwinModules.nix-homebrew
              {
                nix-homebrew = {
                  inherit user;
                  enable = true;
                  taps = {
                    "homebrew/homebrew-core" = homebrew-core;
                    "homebrew/homebrew-cask" = homebrew-cask;
                    "homebrew/homebrew-bundle" = homebrew-bundle;
                  };
                  mutableTaps = false;
                  autoMigrate = true;
                };
              }
              ./hosts/darwin
            ];
          };
        };
      };
  };
}
