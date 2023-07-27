{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, utils }:
    let
      # use tools from given pkgs to extract the db from the download
      getDB = pkgs: pkgs.callPackage ./programs-sqlite.nix { inherit (nixpkgs) rev; };
    in

    # provide db-package for all archs, but scaper/test only for most common
    (utils.lib.eachSystem utils.lib.allSystems (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in
      nixpkgs.lib.recursiveUpdate
        (nixpkgs.lib.optionalAttrs (builtins.elem system utils.lib.defaultSystems) rec {
          packages.updater = pkgs.callPackage ./updater.nix {};
          apps.updater = { type = "app"; program = "${packages.updater}/bin/updater";};
          devShell = with pkgs; mkShell {
            buildInputs = [ nim nimble-unwrapped nimlsp ];
          };
          checks.vmtest = import ./test.nix { inherit pkgs; flake = self; };  # nixpkgs must be set to a revision present in the JSON file
        })
        {
          packages.programs-sqlite = getDB pkgs;
        })
    ) //

    # NixOS module
    {
      nixosModules.programs-sqlite = pass@{ pkgs, ... }: (import ./module.nix { programs-sqlite = (getDB pkgs); }) pass;
    };
}