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

  outputs = { self, nixpkgs, flake-utils, flake-parts, home-manager, disko, darwin, nix-homebrew, homebrew-bundle, homebrew-core, homebrew-cask } @inputs: let user = "%USER%"; in flake-parts.lib.mkFlake {inherit inputs;} {
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

      # Standalone home-manager configuration entrypoint
      # Available through 'home-manager --flake .#username'
      legacyPackages.homeConfigurations = { # only legacyPackages work with home-manager + flake-parts
        mirza = home-manager.lib.homeManagerConfiguration {
          inherit pkgs; # Home-manager requires 'pkgs' instance
          extraSpecialArgs = {inherit inputs;};
          modules = [
            ./modules/nixos/home-manager.nix
          ];
        };
      };
    };

    flake = {
      # NixOS configuration entrypoint
      # Available through 'nixos-rebuild --flake .#hostname'
      nixosConfigurations = {
        hostname = nixpkgs.lib.nixosSystem {
          specialArgs = {inherit inputs;};
          modules = [
            disko.nixosModules.disko
            home-manager.nixosModules.home-manager
            /etc/nixos/hardware-configuration.nix
            ./hosts/nixos
          ];
        };
      };

      # nix-darwin configuration entrypoint
      # Available through 'darwin-rebuild build --flake .#hostname'
      darwinConfigurations = {
        hostname = darwin.lib.darwinSystem {
          specialArgs = {inherit inputs;};
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
