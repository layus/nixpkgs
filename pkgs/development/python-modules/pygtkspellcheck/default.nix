{ lib, fetchPypi, python, buildPythonPackage, pkgconfig, pyenchant }:

buildPythonPackage rec {
  pname = "pygtkspellcheck";
  version = "4.0.5";

  src = fetchPypi {
    inherit pname version;
    sha256 = "0arpgkwzqvwzs8qyf476q1can8jydlb617fi0al640yd25f4d45g";
  };

  propagatedBuildInputs = [ pyenchant ];

  meta = {
    platforms = lib.platforms.unix;
  };
}
