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

      linuxSystems = [ "aarch64-linux" "x86_64-linux" ];

      # adopted from https://github.com/numtide/flake-utils/blob/11707dc2f618dd54ca8739b309ec4fc024de578b/lib.nix#L33
      # which is also MIT licensed; can probably be further simplified
      eachSystemOp = op: systems: f: builtins.foldl' (op f) { } systems;
      eachSystem = eachSystemOp (
        # Merge outputs for each system.
        f: attrs: system:
        let
          ret = f system;
        in
        builtins.foldl' (
          attrs: key:
          attrs
          // {
            ${key} = (attrs.${key} or { }) // {
              ${system} = ret.${key};
            };
          }
        ) attrs (builtins.attrNames ret)
      );
      
    in

    # provide db-package for all archs, but scraper/test only for common Linux
    (eachSystem nixpkgs.lib.systems.doubles.all (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      nixpkgs.lib.recursiveUpdate
        (nixpkgs.lib.optionalAttrs (builtins.elem system linuxSystems) rec {
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
