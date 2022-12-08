{ lib, nimPackages, fetchurl, fetchFromGitHub, coreutils, gnutar }:

let q = fetchFromGitHub {
  owner = "OpenSystemsLab";
  repo = "q.nim";
  rev = "0.0.8";
  sha256 = "sha256-juYoPW1pIizSNeEf203gs/3zm64iHxzV41fKFeSuqaY=";
};
in
nimPackages.buildNimPackage rec {
  pname = "updater";
  version = "0.1";

  nimBinOnly = true;

  nimDefines = [ "ssl" ];

  src = ./src;

  doCheck = true;
  checkPhase = ''testament all'';

  buildInputs = with nimPackages; [
    q
  ];

  propagatedBuildInputs = [ coreutils gnutar ];
}