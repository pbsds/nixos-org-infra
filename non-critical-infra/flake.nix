{
  description = "Non critical nixos org infra";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    colmena = {
      url = "github:zhaofengli/colmena";
      inputs = {
        flake-utils.follows = "flake-utils";
        nixpkgs.follows = "nixpkgs";
        stable.follows = "nixpkgs";
      };
    };
    flake-utils.url = "github:numtide/flake-utils";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    srvos = {
      url = "github:numtide/srvos";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        nixpkgs-stable.follows = "nixpkgs";
      };
    };

    first-time-contribution-tagger = {
      url = "github:Janik-Haag/first-time-contribution-tagger";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
      };
    };
  };

  outputs = { self, nixpkgs, flake-utils, colmena, disko, first-time-contribution-tagger, sops-nix, ... }@inputs:
    let
      importConfig = path: (lib.mapAttrs (name: _value: import (path + "/${name}/default.nix")) (lib.filterAttrs (_: v: v == "directory") (builtins.readDir path)));
      inherit (nixpkgs) lib;
    in
    {

      nixosConfigurations = builtins.mapAttrs
        (_name: value: nixpkgs.lib.nixosSystem {
          inherit lib;
          system = "x86_64-linux";
          specialArgs = {
            inherit inputs;
          };
          modules = [ value disko.nixosModules.disko first-time-contribution-tagger.nixosModule sops-nix.nixosModules.sops ];
          extraModules = [ inputs.colmena.nixosModules.deploymentOptions ];

        })
        (importConfig ./hosts);

      colmena =
        {
          meta = {
            nixpkgs = import inputs.nixpkgs { system = "x86_64-linux"; };
            nodeNixpkgs = builtins.mapAttrs (_: v: v.pkgs) self.nixosConfigurations;
            nodeSpecialArgs = builtins.mapAttrs (_: v: v._module.specialArgs) self.nixosConfigurations;
            specialArgs.lib = lib;
          };
        } // builtins.mapAttrs
          (_: v: {
            imports = v._module.args.modules;
          })
          self.nixosConfigurations;

    } // flake-utils.lib.eachDefaultSystem (system:
      let pkgs = nixpkgs.legacyPackages.${system};
      in {
        devShell =
          pkgs.mkShell {
            buildInputs = with pkgs; [
              colmena.packages.${system}.colmena
              sops
              ssh-to-age
            ];
          };
      });

}
