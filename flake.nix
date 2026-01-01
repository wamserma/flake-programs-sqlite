{
  inputs = {
    nixpkgs.url = "https://channels.nixos.org/nixos-unstable/nixexprs.tar.xz";
    utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, utils }:
    let
      # use tools from given pkgs to extract the db from the download
      getDB = pkgs: pkgs.callPackage ./programs-sqlite.nix { inherit (nixpkgs) rev; };

      # shared NixOS & Home Manager module that extracts the db from its own `pkgs` instance
      # NB: this only works because the `command-not-found` options match exactly between NixOS & Home Manager
      sharedModule = pass@{ pkgs, ... }: (import ./module.nix { programs-sqlite = (getDB pkgs); }) pass;
    in

    # provide db-package for all archs, but scaper/test only for most common
    (utils.lib.eachSystem utils.lib.allSystems (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      nixpkgs.lib.recursiveUpdate
        (nixpkgs.lib.optionalAttrs (builtins.elem system utils.lib.defaultSystems) rec {
          packages.updater = pkgs.callPackage ./updater.nix {};
          apps.updater = { type = "app"; program = "${packages.updater}/bin/updater";};
          devShells.default = with pkgs; mkShell {
            buildInputs = [ nim nimble nimlsp pinact ];
          };
          checks.vmtest = import ./test.nix { inherit pkgs; flake = self; };  # nixpkgs must be set to a revision present in the JSON file
        })
        {
          packages.programs-sqlite = getDB pkgs;
        })
    ) //

    # NixOS & Home Manager modules
    {
      nixosModules.programs-sqlite = sharedModule;
      homeModules.programs-sqlite = sharedModule;
    };
}
