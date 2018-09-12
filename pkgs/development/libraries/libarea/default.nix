{ stdenv, fetchFromGitHub, cmake, pythonPackages
, boost_cmake ? boost166, boost166
}:

let
  boost_python = boost_cmake.override { enablePython = true; inherit (pythonPackages) python; };

in pythonPackages.buildPythonPackage rec {
  name = "libarea-${version}";
  version = "unstable-2018.04.25-g8f8bac8";
  format = "other";

  src = fetchFromGitHub {
    owner = "Heeks";
    repo = "libarea";
    rev = "8f8bac811c10f1f01fda0d742a18591f61dd76ee";
    sha256 = "0pvqz6cabxqdz5y26wnj6alkn8v5d7gkx0d3h8xmg4lvy9r3kh3g";
  };

  buildInputs = [ cmake boost_python ];
}
