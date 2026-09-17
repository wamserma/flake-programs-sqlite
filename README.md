# programs.sqlite for Nix Flake based systems

[![Update Channel Info](https://github.com/wamserma/flake-programs-sqlite/actions/workflows/scrape.yml/badge.svg?branch=main)](https://github.com/wamserma/flake-programs-sqlite/actions/workflows/scrape.yml)

## Do I need this?

Probably not. It is now (now is the year 2026) recommended to use lockable URLs instead of
GitHub repos when setting a nixpkgs input for your flake.
This avoids rate limiting, provides faster downloads via CDNs and brings `programs.sqlite`
built in.

If you still prefer to have your inputs pointed at a GitHub repo, this is for you. It will restore
the command-hinting functionality known from non-flake systems:

```
[me@computer:/tmp]$ cowsay moo
The program 'cowsay' is not in your PATH. It is provided by several packages.
You can make it available in an ephemeral shell by typing one of the following:
  nix-shell -p cowsay
  nix-shell -p neo-cowsay
```

Note that [`command-not-found` might be disabled for repo-based inputs](https://github.com/NixOS/nixpkgs/commit/4241fb5eaeb33e8a673a547d1eb1bb2d3fc7d34f).

This utility works in both cases and detects when you use a tarball as input, in which case the
existing `programs.sqlite` will be reused instead of being downloaded and extracted (again).

## TL;DR

(assuming a flake similar to <https://nixos.wiki/wiki/Flakes#Using_nix_flakes_with_NixOS>)

Add to `inputs` in `flake.nix`:

```nix
flake-programs-sqlite.url = "github:wamserma/flake-programs-sqlite";
flake-programs-sqlite.inputs.nixpkgs.follows = "nixpkgs";
```

Then just add the module.

### NixOS module

Usage with a minimal system flake:

```nix
{
  inputs.nixpkgs.url = "https://nixos.org/channels/nixos-26.05/nixexprs.tar.zst"; # preferred style
  # inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-22.11";  # old stlye or non-channel inputs
  inputs.flake-programs-sqlite.url = "github:wamserma/flake-programs-sqlite";
  inputs.flake-programs-sqlite.inputs.nixpkgs.follows = "nixpkgs";

  outputs = inputs@{ self, nixpkgs, ... }: {

    nixosConfigurations.mymachine = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules =
        [
          (import configuration.nix)
          inputs.flake-programs-sqlite.nixosModules.programs-sqlite
        ];
    };
  };
}
```

The module's functionality is enabled as soon as the module is imported.

### Home Manager module

A Home Manager module is also provided in the Flake output `homeModules.programs-sqlite`.

Like the NixOS module, its functionality is enabled as soon as it's imported.

### alternative: without using a module

Add `flake-programs-sqlite` to the arguments of the flake's `outputs` function.

Add `programs-sqlite-db = flake-programs-sqlite.packages.${system}.programs-sqlite`
to the `specialArgs` argument of `lib.nixosSystem`.

Add `programs-sqlite-db`to the inputs of your system configuration (`configuration.nix`)
and to the configuration itself add:

```nix
programs.command-not-found.dbPath = programs-sqlite-db;
```

## Why?

NixOS systems configured with flakes and thus lacking channels usually have a broken
`command-not-found`. The reason is that the backing database `programs.sqlite` is only
available on channels. The problem is that the channel URL can not be determined from
the `nixpkgs` revision alone, as it also contains a build number.

<details>
  <summary>
  <code>command-not-what?</code>
  </summary>

  Bash and other shells have a special handler that is invoked when an unknown command
  is issued to the shell. For bash this is `command_not_found_handler`.

  `command-not-found` is [a Perl script](https://github.com/NixOS/nixpkgs/blob/7c44c865ee736afba33ee8788b59e4a123800437/nixos/modules/programs/command-not-found/command-not-found.pl)
  that is hooked into this handler when
  the option [`programs.command-not-found.enable`](https://search.nixos.org/options?show=programs.command-not-found.enable)
  is set to `true`. This Perl script evaluates a pre-made database to suggest
  packages that might be able to provide the command.

  The pre-made database is generated as part of a channel, hence pure-flake-systems
  do not have access to it. This flake extracts the database from the channels
  and passes it to the `command-not-found` script to restore functionality that
  was previously only available when using channels.
</details>

This is an attempt to provide a usable solution, motivated by <https://discourse.nixos.org/t/how-to-specify-programs-sqlite-for-command-not-found-from-flakes/22722/3>

## How?

The channel page is regularly scraped for the revision and file hashes, then a
[lookup table](./sources.json) from revisions to URL and hashes is amended with any
new information.
The lookup table is used to create a fixed-output-derivation (FOD) for `programs.sqlite`
based on the revision of `nixpkgs` passed as input of this flake.

## Usage

see TL:DR above

## Development

The flake provides a minimal devshell, but hacking on the code with a editor and
running `nix run .#updater` is valid, too.

Development happens on the `tooling` branch, which is then merged into the `main`
branch. Updates to the JSON file go directly to `main`. Releases of the tooling are
also cut from the `tooling` branch. There are no releases for the JSON files.

## Fetching selected channel revisions

e.g. to fetch info for older revisions/releases from before this project was started

```sh
[ -f sources.json ] || echo {} > sources.json
nix run github:wamserma/flake-programs-sqlite#updater -- --dir:. --channel:https://releases.nixos.org/nixos/20.03/nixos-20.03.2400.ff1b66eaea4
```

Multiple channels/revisions may be passed for a single run.  
If no channel is given, the current channels are guessed and their latest revisions are fetched.

## Alternatives

- [nix-index](https://github.com/bennofs/nix-index#usage-as-a-command-not-found-replacement)

## Licensing

The Nim code to scrape the metadata is released under MIT License.  
The Nix code to provide the FODs is released under MIT License.  
The database itself (JSON) is public domain.
