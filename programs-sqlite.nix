{ lib, fetchurl, pkgs, rev }:
let
  meta = (lib.importJSON ./sources.json)."${rev}";
in
pkgs.stdenvNoCC.mkDerivation {
  pname = "programs-sqlite";
  version = rev;

  src = fetchurl {
    url = "https://releases.nixos.org${meta.url}";
    sha256 = meta.nixexprs_hash;
  };
  dontConfigure = true;
  dontBuild = true;
  installPhase = ''
    cp programs.sqlite $out
    '';
  outputHashAlgo = "sha256";
  outputHashMode = "flat";
  outputHash = meta.programs_sqlite_hash;
}