{ lib, pkgs, fetchFromGitHub, busybox, gnutar, xz }:

let
  q = fetchFromGitHub {
    owner = "OpenSystemsLab";
    repo = "q.nim";
    rev = "0.0.8";
    sha256 = "sha256-juYoPW1pIizSNeEf203gs/3zm64iHxzV41fKFeSuqaY=";
  };
in
pkgs.buildNimPackage {
  pname = "updater";
  version = "0.3.0";

  nimRelease = true;

  nimDefines = [ "ssl" "useOpenssl3" ];

  src = ./src;
  # set store-relative paths for dependencies, so they can be discovered in a nix bundle
  postPatch = ''
    substituteInPlace updater/updater.nim --replace 'systemXZ = "xz"' 'systemXZ = "${xz}/bin/xz"'
    substituteInPlace updater/updater.nim --replace 'systemTar = "tar"' 'systemTar = "${gnutar}/bin/tar"'
    substituteInPlace updater/updater.nim --replace 'systemSha256 = "sha256sum"' 'systemSha256 = "${busybox}/bin/sha256sum"'
    substituteInPlace updater/updater.nim --replace 'systemShell = "/bin/sh"' 'systemShell = "${busybox}/bin/sh"'
  '';

  doCheck = true;
  checkPhase = ''testament all'';

  nativeBuildInputs = [ pkgs.removeReferencesTo ];
  buildInputs = [
    q pkgs.openssl
  ] ++
  [ pkgs.nim-unwrapped ];  # needs to be declared als buildInput, so the path is known for the postFixup

  propagatedBuildInputs = [ busybox gnutar xz ];
  postFixup = ''
    remove-references-to -t ${pkgs.nim-unwrapped} $out/bin/updater
  '';
}
