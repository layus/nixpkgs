{ lib, fetchPypi, python, buildPythonPackage, gobject-introspection, gtk3 }:

buildPythonPackage rec {
  pname = "pygtkspellcheck";
  version = "4.0.5";

  src = fetchPypi {
    inherit pname version;
    sha256 = "0arpgkwzqvwzs8qyf476q1can8jydlb617fi0al640yd25f4d45g";
  };

  buildInputs = [ gtk3 gobject-introspection ];
  propagatedBuildInputs = with python.pkgs; [ pygobject3 pyenchant ];

  meta = {
    platforms = lib.platforms.unix;
  };
}
