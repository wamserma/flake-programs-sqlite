{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, utils }:
    utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in
      rec {
        packages.updater = pkgs.callPackage ./updater.nix {};
        apps.updater = { type = "app"; program = "${packages.updater}/bin/updater";};
        devShell = with pkgs; mkShell {
          buildInputs = [ nim nimble-unwrapped ];
        };
        packages.programs-sqlite = pkgs.callPackage ./programs-sqlite.nix { rev = nixpkgs.rev; };
      });
}
