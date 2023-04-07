{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, utils }:
    utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        rev2db = rev: pkgs.callPackage ./programs-sqlite.nix { inherit rev; };
      in
      rec {
        packages.updater = pkgs.callPackage ./updater.nix {};
        apps.updater = { type = "app"; program = "${packages.updater}/bin/updater";};
        devShell = with pkgs; mkShell {
          buildInputs = [ nim nimble-unwrapped ];
        };
        packages.programs-sqlite = rev2db nixpkgs.rev;
        nixosModules.programs-sqlite = import ./module.nix { programs-sqlite = packages.programs-sqlite; };
        checks.vmtest = import ./test.nix { inherit pkgs; flake = self; };  # nixpkgs must be set to a revision presen in the JSON file
      });
}
