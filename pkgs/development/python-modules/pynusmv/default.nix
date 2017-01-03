{ stdenv, buildPythonPackage, python
, pkgs
, pyparsing, sphinx, isPy3k }:

buildPythonPackage rec {
  name = "pynusmv-${version}";
  version = "1.0rc3";

  src = pkgs.fetchurl {
    url = "mirror://pypi/p/pynusmv/${name}.tar.gz";
    sha256 = "1a3211337k9qrf7qph513av0h8405gsiaw0b2x5c01d0h8rg7q4v";
  };

  disabled = !isPy3k;
  doCheck = false;

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

  propagatedBuildInputs = [ pyparsing ];

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
  ];
}

