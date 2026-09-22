{ lib, fetchurl, pkgs, nixpkgsRev, nixpkgsPath ? null }:
let
  metaByRev = (lib.importJSON ./sources.json)."${nixpkgsRev}" or (lib.importJSON ./latest.json).${lib.trivial.release};
  localDbPath = lib.mapNullable (p:
      let pp = p + "/programs.sqlite"; in
      if lib.pathIsRegularFile pp then pp else null
    ) nixpkgsPath;
  useLocalDb = localDbPath != null;
  localDbHash = builtins.hashFile "sha256" localDbPath;
  meta = if !builtins.isList metaByRev then metaByRev else
           if !useLocalDb then
             lib.trivial.warn "Revision is present on multiple channels, picking first one from DB. Consider switching the flake-input to tarballs and lockable HTTP URLs." (builtins.head metaByRev)
           else
             builtins.head (builtins.filter (x: x.programs_sqlite_hash == localDbHash) metaByRev)
         ;

in
pkgs.stdenvNoCC.mkDerivation {
  pname = "programs-sqlite";
  version = meta.name;
  dontConfigure = true;
  dontPatch = true;
  dontUpdateAutotoolsGnuConfigScripts = true;
  dontBuild = true;
  dontFixup = true;
  dontUnpack = useLocalDb;
  preferLocalBuild = true;

  src = if useLocalDb then nixpkgsPath else
    fetchurl {
      url = "https://releases.nixos.org${meta.url}";
      sha256 = meta.nixexprs_hash;
    };
    
  installPhase = if useLocalDb then ''
      cp $src/programs.sqlite $out
    '' else ''
      cp programs.sqlite $out
    '';
  outputHashAlgo = "sha256";
  outputHashMode = "flat";
  outputHash = meta.programs_sqlite_hash;
}
