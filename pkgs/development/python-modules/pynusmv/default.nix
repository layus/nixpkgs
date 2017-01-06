{ stdenv, buildPythonPackage, pkgs
, python, pyparsing, sphinx, requests2, isPy3k }:

buildPythonPackage rec {
  name = "pynusmv-${version}";
  version = "1.0rc5";

  src = pkgs.fetchurl {
    #url = "mirror://pypi/p/pynusmv/${name}.tar.gz";
    #sha256 = "0yw56w05v0f26gy6kz73smq4k5vhgfwgk5qmygkq1mkdlzvac44r";

    #url = "https://github.com/LouvainVerificationLab/pynusmv/archive/${version}.zip";
    #sha256 = "0wvqazlwh9javqm7il0nrsicjsg7b1pgl9zfx4jai7ilgbzmfcjz";

    url = "https://github.com/LouvainVerificationLab/pynusmv/archive/master.zip";
    sha256 = "1kn2xja79213d8w5scm1c32rai2zrc28fszw6r9y4brkg7r578jf";
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
  ];
}

