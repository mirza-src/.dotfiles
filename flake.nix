{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    devenv = {
      url = "github:cachix/devenv";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    chaotic = {
      url = "github:chaotic-cx/nyx/nyxpkgs-unstable";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nur = {
      url = "github:nix-community/NUR";
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
    hyprland = {
      url = "github:hyprwm/Hyprland";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hyprland-plugins = {
      url = "github:hyprwm/hyprland-plugins";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.hyprland.follows = "hyprland";
    };
    quickshell = {
      url = "git+https://git.outfoxxed.me/outfoxxed/quickshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    vscode-extensions = {
      url = "github:nix-community/nix-vscode-extensions";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    rke2 = {
      url = "github:numtide/nixos-rke2";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-gaming = {
      url = "github:fufexan/nix-gaming";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    aagl = {
      url = "github:ezKEa/aagl-gtk-on-nix";
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
      "https://ezkea.cachix.org"
      "https://devenv.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "chaotic-nyx.cachix.org-1:HfnXSw4pj95iI/n17rIDy40agHj12WfF+Gqk6SonIT8="
      "nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svXaZF/Ees8vCUUs4="
      "nixpkgs-wayland.cachix.org-1:3lwxaILxMRkVhehr5StQprHdEo4IrE8sRho9R9HOLYA="
      "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
      "ezkea.cachix.org-1:ioBmUbJTZIKsHmWWXPe1FSFbeVe+afhfgqgTSNd34eI="
      "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
    ];
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      home-manager,
      devenv,
      chaotic,
      nur,
      lanzaboote,
      asus-dialpad-driver,
      hyprland,
      hyprland-plugins,
      quickshell,
      vscode-extensions,
      rke2,
      nix-gaming,
      aagl,
      ...
    }@inputs:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        lib = nixpkgs.lib;
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
          # Adding an overlay to allow access to all packages through nixpkgs
          overlays = [
            vscode-extensions.overlays.default
            self.overlays.default
          ];
        };
      in
      {
        packages = import ./pkgs { inherit pkgs lib inputs; } // {
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
                hyprland.homeManagerModules.default
                chaotic.homeManagerModules.default
                self.homeManagerModules.default
                ./users/.shared
                ./users/${username}
              ];
            }
          );
        };

        devShells.default = devenv.lib.mkShell {
          inherit inputs pkgs;
          modules = [
            (
              { config, pkgs, ... }:
              {
                name = "dotfiles";

                # https://devenv.sh/reference/options/
                packages = with pkgs; [
                  hello
                  quickshell-with-modules
                  qt6.qtdeclarative
                ];
              }
            )
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
          specialArgs = { inherit self inputs hostname; };
          modules = [
            hyprland.nixosModules.default
            nur.modules.nixos.default
            chaotic.nixosModules.nyx-cache
            chaotic.nixosModules.nyx-overlay
            chaotic.nixosModules.nyx-registry
            rke2.nixosModules.default
            home-manager.nixosModules.home-manager
            aagl.nixosModules.default
            self.nixosModules.default
            ./hosts/.shared
            ./hosts/${hostname}
          ];
        }
      );

      overlays.default =
        final: prev:
        import ./pkgs {
          inherit inputs;
          inherit (nixpkgs) lib;
          pkgs = prev; # Using prev to allow merging of nested packages like under `haskellPackages`
        };

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
    };
}
