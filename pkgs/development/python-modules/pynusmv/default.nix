{ stdenv, buildPythonPackage, pkgs
, python, pyparsing, sphinx, requests2, nose, isPy3k }:

buildPythonPackage rec {
  name = "pynusmv-${version}";
  version = "master";

  src = pkgs.fetchurl {
    url = "https://github.com/LouvainVerificationLab/pynusmv/archive/master.zip";
    sha256 = "12n12302sd2p5yb29s4m6g94pjmcgndc27q6iylshnzj83j6xh8d";
  };

  disabled = !isPy3k;
  #doCheck = false;

  hardeningDisable = "format"; 
  patches = [ ./cudd.patch ];

  preFixup = let rpath = stdenv.lib.makeLibraryPath [
    stdenv.cc.cc
    stdenv.cc.cc.lib
    stdenv.glibc.dev
    pkgs.expat
    python
    "$out/${python.sitePackages}"
  ]; in ''
    find $out -name '*.so' -exec patchelf --set-rpath ${rpath} {} \;
  '';

  propagatedBuildInputs = [ pyparsing requests2 ];

  buildInputs = [
    pkgs.which
    pkgs.gcc
    pkgs.flex
    pkgs.bison
    pkgs.swig
    pkgs.unzip
    pkgs.ncurses
    pkgs.readline
    pkgs.patchelf
    pkgs.expat.dev
    sphinx
    nose
  ];
}

