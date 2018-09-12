{ stdenv, fetchFromGitHub, cmake, pythonPackages
, opencascade, wxGTK, libGL, libGLU, xorg, gettext, libarea
}:

pythonPackages.buildPythonApplication rec {
  name = "heekscad-${version}";
  version = "2018.08.14-g0352241";
  format = "other";

  src = fetchFromGitHub {
    owner = "Heeks";
    repo = "heekscad";
    rev = "0352241bb50041535264c65ef86d15ca7ae52dc9";
    sha256 = "0j8nvfdra4p5xlg1154f9a61vac4vimmfq0w76km0r49wlrxgdl3";
  };

  patches = [ ./includes-install-path.patch ];

  #cmakeFlags = [ "-DCMAKE_CXX_FLAGS=-std=c++11" ];
  cmakeFlags = [ "-DCMAKE_BUILD_TYPE=Debug" ];
  makeFlags = [ "VERBOSE=1" ];

  buildInputs = [ cmake opencascade wxGTK libGL libGLU xorg.libX11 gettext libarea ];
}
