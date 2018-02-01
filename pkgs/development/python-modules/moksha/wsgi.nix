
{ buildPythonPackage, pkgs }:

buildPythonPackage rec {
    pname = "moksha.wsgi";
    version = "1.0.0";

    src = pkgs.fetchurl {
      url = "mirror://pypi/m/${pname}/${pname}-${version}.tar.gz";
      sha256 = "09l3f02da1d46rc0dcl8cg4zkdpyd8b8q1q73wqkr24dmgycab25";
    };

}

