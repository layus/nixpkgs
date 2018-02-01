{ buildPythonPackage, pkgs }:


buildPythonPackage rec {
  pname = "moksha";
  version = "1.0.0";

  src = pkgs.fetchurl {
    url = "mirror://pypi/m/${pname}/${pname}-${version}.tar.gz";
    sha256 = "1kn384fz754nra7ps2da0ddsbb0r0w498iis2w1gm7glpkxp7lr0";
  };

}
