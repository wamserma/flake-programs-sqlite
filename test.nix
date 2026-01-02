{ pkgs, flake } :
let

  # Single source of truth for all VM constants
  system = "x86_64-linux";

  # NixOS module shared between server and client
  sharedModule = {
    virtualisation = {
      graphics = false;
      # jnsgruk suggests these limits
      cores = 2;
      memorySize = 5120;
      diskSize = 10240;
    };
    programs.command-not-found.enable = true;
    environment.systemPackages = [ pkgs.gnugrep pkgs.coreutils ];
    users = {
      mutableUsers = false;
      users.root = {
        password = "";
        initialHashedPassword = pkgs.lib.mkForce null;
        hashedPasswordFile = pkgs.lib.mkForce null;
      };
    };
  };

  programs-sqlite-db = flake.packages.${system}.programs-sqlite;
  rev = flake.inputs.nixpkgs.rev;

  programs-sqlite-db-for-fallback-test = pkgs.callPackage ./programs-sqlite.nix {
    rev = "0000000000000000000000000000000000000000";
  };

in
  # for the fallback test, we need a rev not in sources.json
  assert (false == (pkgs.lib.importJSON ./sources.json) ? revForFallbackTest);

  pkgs.testers.nixosTest {
  name = "packages-sqlite-test";
  nodes = {
    directConfig = { config, pkgs, ... }: {
      imports = [ sharedModule ];
      programs.command-not-found.dbPath = programs-sqlite-db;
    };

    moduleConfig = { config, pkgs, ... }: {
      imports = [ sharedModule flake.nixosModules.programs-sqlite ];
    };

    directConfigFallback = { config, pkgs, ... }: {
      imports = [ sharedModule ];
      programs.command-not-found.dbPath = programs-sqlite-db-for-fallback-test;
    };
  };

  testScript = ''
    import json;

    def check(machine, expected_rev, db):
        with open(f"${flake.outPath}/{db}", "r") as f:
            hashes = json.load(f)

        with subtest("check test"):
          errmsg = f"expected rev {expected_rev} not found in {db}"
          assert hashes.get(expected_rev) is not None, errmsg
  
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
          assert hashes.get(expected_rev).get("programs_sqlite_hash") == cnfdbhash, "incorrect programs.sqlite is used"

        machine.shutdown()

    check(directConfig, "${rev}", "sources.json")
    check(moduleConfig, "${rev}", "sources.json")
    check(directConfigFallback, "${pkgs.lib.trivial.release}", "latest.json")
  '';
}
