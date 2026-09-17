{
  inputs = {
    nixpkgs.url = "https://channels.nixos.org/nixos-unstable/nixexprs.tar.xz";
  };

  outputs = { self, nixpkgs }:
    let
      # use tools from given pkgs to extract the db from the download
      getDB = pkgs: pkgs.callPackage ./programs-sqlite.nix { inherit (nixpkgs) rev; };

      # shared NixOS & Home Manager module that extracts the db from its own `pkgs` instance
      # NB: this only works because the `command-not-found` options match exactly between NixOS & Home Manager
      sharedModule = pass@{ pkgs, ... }: (import ./module.nix { programs-sqlite = (getDB pkgs); }) pass;

      # for readability and dry code
      inherit (nixpkgs) lib;
      pkgsFor = system: nixpkgs.legacyPackages.${system};
      linuxSystems = [ "aarch64-linux" "x86_64-linux" ];
      
      # provide db-package for all archs, but scraper/test/devshell only for common Linux
      dbPackages = lib.genAttrs lib.systems.doubles.all (system: {
        programs-sqlite = getDB (pkgsFor system);
      });

      updaterPackages = lib.genAttrs linuxSystems (system: {
        updater = (pkgsFor system).callPackage ./updater.nix {};
      });
  in
  {
    packages = lib.recursiveUpdate dbPackages updaterPackages;
    apps = lib.genAttrs linuxSystems (system: {
      updater = { type = "app"; program = "${updaterPackages.${system}.updater}/bin/updater"; };
    });
    devShells = lib.genAttrs linuxSystems (system: {
      default = with (pkgsFor system); mkShell {
            buildInputs = [ nim nimble nimlsp pinact ];
      };      
    });
    checks = lib.genAttrs linuxSystems (system: {
      # nixpkgs must be set to a revision present in the JSON file for the test to succeed
      vmtest = import ./test.nix { pkgs = pkgsFor system; flake = self; };
    });

    # NixOS & Home Manager modules
    nixosModules.programs-sqlite = sharedModule;
    homeModules.programs-sqlite = sharedModule;
  };
}
