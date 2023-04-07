{ programs-sqlite }: ({ config, lib, ... }:
with lib;
let cfg = config.programs-sqlite;
in {
  options.programs-sqlite = {
    enable = mkEnableOption (lib.mdDoc "fetching a `programs.sqlite` for `command-not-found`") //
    {
      default = true;
      description = lib.mdDoc ''
        fetch a `programs.sqlite` file matching the current nixpks revision and use it for the
        `command-not-found` hook.
      '';
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = config.programs.command-not-found.enable;
        message = "Using programs.sqlite was requested but command-not-found itself is not enabled.";
        }
    ];

    programs.command-not-found.dbPath = programs-sqlite;
  };
})