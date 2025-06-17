{
  description = "Configuration for MacOS and NixOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-utils.url = "github:numtide/flake-utils";
    hyprland.url = "github:hyprwm/Hyprland";
    hyprland-plugins = {
      url = "github:hyprwm/hyprland-plugins";
      inputs.hyprland.follows = "hyprland";
    };
    nur = {
      url = "github:nix-community/NUR";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    chaotic = {
      url = "github:chaotic-cx/nyx/nyxpkgs-unstable";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-gaming = {
      url = "github:fufexan/nix-gaming";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
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
  };

  nixConfig = {
    extra-substituters = [
      "https://nix-community.cachix.org"
      "https://chaotic-nyx.cachix.org/"
      "https://nix-gaming.cachix.org"
      "https://nixpkgs-wayland.cachix.org"
      "https://hyprland.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "chaotic-nyx.cachix.org-1:HfnXSw4pj95iI/n17rIDy40agHj12WfF+Gqk6SonIT8="
      "nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svXaZF/Ees8vCUUs4="
      "nixpkgs-wayland.cachix.org-1:3lwxaILxMRkVhehr5StQprHdEo4IrE8sRho9R9HOLYA="
      "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
    ];
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-parts,
      flake-utils,
      hyprland,
      hyprland-plugins,
      nur,
      chaotic,
      nix-gaming,
      home-manager,
      ...
    }@inputs:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        flake-parts.flakeModules.easyOverlay
      ];
      systems = flake-utils.lib.defaultSystems;

      perSystem =
        {
          config,
          system,
          pkgs,
          lib,
          ...
        }:
        {
          packages = import ./pkgs pkgs;

          # Adding an overlay to allow access to packages through nixpkgs
          overlayAttrs = config.packages;

          # Standalone home-manager configuration entrypoint
          # Available through 'home-manager switch --flake .#username'
          # HACK: only legacyPackages work with home-manager + flake-parts
          legacyPackages.homeConfigurations = lib.genAttrs (self.lib.listNixModules ./users) (
            username:
            home-manager.lib.homeManagerConfiguration {
              inherit pkgs; # Home-manager requires 'pkgs' instance
              extraSpecialArgs = {
                inherit self inputs username;
              };
              modules = [
                hyprland.homeManagerModules.default
                chaotic.homeManagerModules.default
                self.homeManagerModules.default
                ./users/.shared
                ./users/${username}
              ];
            }
          );
        };

      flake = {
        # NixOS configuration entrypoint
        # Available through 'nixos-rebuild switch --flake .#hostname'
        nixosConfigurations = nixpkgs.lib.genAttrs (self.lib.listNixModules ./hosts) (
          hostname:
          nixpkgs.lib.nixosSystem {
            specialArgs = { inherit self inputs hostname; };
            modules = [
              hyprland.nixosModules.default
              nur.modules.nixos.default
              chaotic.nixosModules.nyx-cache
              chaotic.nixosModules.nyx-overlay
              chaotic.nixosModules.nyx-registry
              home-manager.nixosModules.home-manager
              self.nixosModules.default
              ./hosts/.shared
              ./hosts/${hostname}
            ];
          }
        );
        modules = import ./modules;
        nixosModules = import ./modules/nixos {
          inherit self;
          inherit (nixpkgs) lib;
        };
        homeManagerModules = import ./modules/home-manager {
          inherit self;
          inherit (nixpkgs) lib;
        };
        lib = import ./lib {
          inherit self;
          inherit (nixpkgs) lib;
        };
      };
    };
}
