{ stdenv, fetchFromGitHub, cmake, pythonPackages
, opencascade, wxGTK, libGL, libGLU, xorg, gettext, heekscad, libarea, opencamlib
}:

pythonPackages.buildPythonPackage rec {
  name = "heekscnc-${version}";
  version = "unstable-2018.04.25-gad15af5";
  format = "other";

  src = fetchFromGitHub {
    owner = "Heeks";
    repo = "heekscnc";
    rev = "ad15af5c057998047ffefdc60c44a4bcd14a1d8a";
    sha256 = "060zvd3yk7wairg4dswkpp23l5v6s2cww2mzz0nlcqmlnf3l40xp";
  };

  postPatch = ''
    ln -s ${heekscad}/include/heekscad .
    pwd
    ls -l
  '';
  buildInputs = [ cmake opencascade wxGTK libGL libGLU xorg.libX11 gettext libarea heekscad opencamlib ];
}
