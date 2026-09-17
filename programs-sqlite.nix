{ lib, fetchurl, pkgs, nixpkgsRev, nixpkgsPath ? null }:
let
  meta = (lib.importJSON ./sources.json)."${nixpkgsRev}" or (lib.importJSON ./latest.json).${lib.trivial.release};
  localDbPath = lib.mapNullable (p:
      let pp = p + "/programs.sqlite"; in
      if lib.pathIsRegularFile pp then pp else null
    ) nixpkgsPath;
  useLocalDb = localDbPath != null;
in
pkgs.stdenvNoCC.mkDerivation {
  pname = "programs-sqlite";
  version = meta.name;
  dontConfigure = true;
  dontBuild = true;
  dontUnpack = useLocalDb;

  src = if useLocalDb then nixpkgsPath else
    fetchurl {
      url = "https://releases.nixos.org${meta.url}";
      sha256 = meta.nixexprs_hash;
    };
    
  installPhase = ''
    cp programs.sqlite $out
    '';
  outputHashAlgo = "sha256";
  outputHashMode = "flat";
  outputHash = meta.programs_sqlite_hash;
}
