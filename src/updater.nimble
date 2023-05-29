# Package

version       = "0.2.1"
author        = "Markus S. Wamser"
description   = "A small tool to build lookup-tables for programs.sqlite from nixpkgs revisions"
license       = "MIT"
srcDir        = "updater"
bin           = @["updater"]


# Dependencies

requires "nim >= 1.6.10"
requires "q >= 0.0.7"
