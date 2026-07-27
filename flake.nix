{
  inputs = {
    nixpkgs.url = "https://channels.nixos.org/nixos-unstable/nixexprs.tar.xz";
  };

  outputs = { self, nixpkgs }:
    let
      inherit (nixpkgs) lib;

      systems = builtins.attrNames nixpkgs.legacyPackages;
      commonSystems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-darwin"
        "x86_64-linux"
      ];
      updaterSystems = [
        "aarch64-linux"
        "x86_64-linux"
      ];

      forAllSystems = lib.genAttrs systems;
      forCommonSystems = lib.genAttrs commonSystems;
      forUpdaterSystems = lib.genAttrs updaterSystems;
      pkgsFor = system: nixpkgs.legacyPackages.${system};

      # use tools from given pkgs to extract the db from the download
      getDB = pkgs: pkgs.callPackage ./programs-sqlite.nix { inherit (nixpkgs) rev; };

      # shared NixOS & Home Manager module that extracts the db from its own `pkgs` instance
      # NB: this only works because the `command-not-found` options match exactly between NixOS & Home Manager
      sharedModule = pass@{ pkgs, ... }: (import ./module.nix { programs-sqlite = (getDB pkgs); }) pass;
    in

    {
      # provide db-package for all archs, but scraper/test only where supported
      packages = forAllSystems (system:
        let
          pkgs = pkgsFor system;
        in
        {
          programs-sqlite = getDB pkgs;
        } // lib.optionalAttrs (builtins.elem system updaterSystems) {
          updater = pkgs.callPackage ./updater.nix {};
        });

      apps = forUpdaterSystems (system: {
        updater = {
          type = "app";
          program = "${self.packages.${system}.updater}/bin/updater";
        };
      });

      devShells = forCommonSystems (system:
        let
          pkgs = pkgsFor system;
        in
        {
          default = with pkgs; mkShell {
            buildInputs = [ nim nimble nimlsp pinact ];
          };
        });

      checks = forUpdaterSystems (system:
        let
          pkgs = pkgsFor system;
        in
        {
          # nixpkgs must be set to a revision present in the JSON file
          vmtest = import ./test.nix { inherit pkgs; flake = self; };
        });

      # NixOS & Home Manager modules
      nixosModules.programs-sqlite = sharedModule;
      homeModules.programs-sqlite = sharedModule;
    };
}
