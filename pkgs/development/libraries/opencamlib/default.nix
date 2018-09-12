{ stdenv, fetchFromGitHub, pythonPackages, cmake
, python2, boost166, boost_cmake ? boost166
}:

let
  boost_python = boost_cmake.override { enablePython = true; inherit (pythonPackages) python; };

in pythonPackages.buildPythonPackage rec {
  pname = "opencamlib";
  version = "2018.08";
  name = "${pname}-${version}";
  format = "other";

  src = fetchFromGitHub {
    owner = "aewallin";
    repo = pname;
    rev = version;
    sha256 = "10axlkg1xgb197a27zy5h1x8vfwbx5y05h1vna793ac0dqgn5lcf";
  };

  postPatch = ''
    echo -n ${version} > src/git-tag.txt
  '';

  cmakeFlags = [ "-DMY_VERSION=${version}" ];

  enableParallel = true;

  buildInputs = [ cmake python2 boost_python ];
}
