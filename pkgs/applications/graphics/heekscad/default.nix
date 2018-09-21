{ stdenv, stdenvGcc5, fetchFromGitHub, cmake, pythonPackages
, opencascade, wxGTK30, libGL, libGLU, xorg, gettext, libarea, opencamlib
, ... }:

let
  wxGTK = wxGTK30.override { stdenv = stdenvGcc5; };

in stdenvGcc5.mkDerivation rec {
  name = "heekscad-${version}";
  version = "2018.08.14-g0352241";
  format = "other";

  sourceRoot = ".";
  srcs = [
    (fetchFromGitHub rec {
      name = repo;
      owner = "Heeks";
      repo = "heekscad";
      rev = "0352241bb50041535264c65ef86d15ca7ae52dc9";
      sha256 = "0j8nvfdra4p5xlg1154f9a61vac4vimmfq0w76km0r49wlrxgdl3";
    })
    (fetchFromGitHub rec {
      name = repo;
      owner = "Heeks";
      repo = "heekscnc";
      rev = "ad15af5c057998047ffefdc60c44a4bcd14a1d8a";
      sha256 = "060zvd3yk7wairg4dswkpp23l5v6s2cww2mzz0nlcqmlnf3l40xp";
    })
  ];

  patches = [
    ./includes-install-path.patch
    ./fixes.patch
  ];

  buildCommand = ''
    unpackPhase
    unpackPhase () { true; }
    unset buildCommand
    unset srcs

    for dir in heeks{cad,cnc}; do
      pushd $dir
        genericBuild
      popd
      unset patches
    done
  '';

  #buildPhase = ''
  #  buildPhase
  #  installPhase

  #  cd ../../heekscnc
  #  eval "$configurePhase"
  #  buildPhase
  #'';

  cmakeFlags = [
    "-DCMAKE_CXX_FLAGS=-std=c++11"
    "-DCMAKE_CXX_FLAGS_DEBUG=-ggdb"
    "-DCMAKE_BUILD_TYPE=Debug"
    #"-DwxWidgets_CONFIG_EXECUTABLE=${wxGTK}/bin/wx-config"
    #"-DPYTHON_EXECUTABLE=${pythonPackages.python}/bin/python2"
    #"-DPYTHON_LIBRARY=${pythonPackages.python}/lib/libpython2.7.so"
    "-DOpenGL_GL_PREFERENCE=GLVND"
  ];
  #makeFlags = [ "VERBOSE=1" ];

  buildInputs = [ cmake opencascade wxGTK libGL libGLU xorg.libX11 gettext libarea opencamlib ];
  propagatedBuildInputs = [ pythonPackages.wxPython ];

  dontStrip = true;
  hardeningDisable = [ "all" ];
}

#pythonPackages.buildPythonPackage rec {
#  name = "heekscnc-${version}";
#  version = "unstable-2018.04.25-gad15af5";
#  format = "other";
#}
