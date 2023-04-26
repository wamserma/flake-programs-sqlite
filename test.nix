{ pkgs, flake } :
let

  # Single source of truth for all VM constants
  system = "x86_64-linux";

  # NixOS module shared between server and client
  sharedModule = {
    virtualisation.graphics = false;
    programs.command-not-found.enable = true;
    environment.systemPackages = [ pkgs.gnugrep pkgs.coreutils ];
  };

  programs-sqlite-db = flake.packages.${system}.programs-sqlite;
  rev = flake.inputs.nixpkgs.rev;

in pkgs.nixosTest {
  name = "packages-sqlite-test";
  nodes = {
    directConfig = { config, pkgs, ... }: {
      imports = [ sharedModule ];
      users = {
        mutableUsers = false;
        users = {
          root.password = "";
        };
      };
      programs.command-not-found.dbPath = programs-sqlite-db;
    };

    moduleConfig = { config, pkgs, ... }: {
      imports = [ sharedModule flake.nixosModules.programs-sqlite ];
      users = {
        mutableUsers = false;
        users = {
          root.password = "";
        };
      };
    };
  };

  testScript = ''
    import json;

    with open("${flake.outPath}/sources.json") as f:
      hashes = json.load(f)

    def check(machine):
        machine.start()
        machine.wait_for_unit("multi-user.target")

        with subtest("check functionality"):
          err, response = machine.execute("command-not-found ponysay 2>&1")
          print(response)
          expected1 = "The program 'ponysay' is not in your PATH. You can make it available in an"
          expected2 = "ephemeral shell by typing:"
          expected3 = "nix-shell -p ponysay"
          assert expected1 in response and expected2 in response and expected3 in response, "command-not-found does nor work"

        with subtest("check database"):
          cnfsrc = machine.succeed("readlink $(which command-not-found)").strip()
          cnfdb = machine.succeed("grep -m 1 dbPath '" + cnfsrc + "' | cut -d '" + '"' + "' -f 2").strip()
          cnfdbhash = machine.succeed("sha256sum " + cnfdb + " | cut -d ' ' -f 1").strip()
          assert hashes.get("${rev}").get("programs_sqlite_hash") == cnfdbhash, "incorrect programs.sqlite is used"

        machine.shutdown()

    check(directConfig)
    check(moduleConfig)
  '';
}