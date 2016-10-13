{ pkgs, lib, pythonPackages }:
with lib;

let
  webpy-custom = pythonPackages.buildPythonPackage rec {
    version = "0.40.dev0";
    name = "web.py-${version}";

    src = pkgs.fetchurl {
      url = "mirror://pypi/w/web.py/web.py-${version}.tar.gz";
      sha256 = "18v91c4s683r7a797a8k9p56r1avwplbbcb3l6lc746xgj6zlr6l";
    };

    doCheck = false;

    meta = {
      description = "Makes web apps";
      longDescription = ''
        Think about the ideal way to write a web app.
        Write the code to make it happen.
      '';
      homepage = "http://webpy.org/";
      license = licenses.publicDomain;
      maintainers = with maintainers; [ layus ];
    };
  };

  flup-dev = pythonPackages.buildPythonPackage rec {
      name = "flup-1.0.3.dev20151210";
      src = pkgs.fetchurl {
        url = "https://pypi.python.org/packages/ea/16/c57d1afc041c0208eeae5751fc481d2cd264fb9fa9b1c83b3b422e591f6a/flup-1.0.3.dev20151210.tar.gz";
        sha256 = "1a0qain2qiqfxcfx4q9xd05ghlkxqf4i6z834f02vj04qm2kzm4r";
      };
    };

  pyzmq-with-zeromq4 = let
    customPythonPackages = (pythonPackages.override {
                       # Ouch!
      pkgs = pkgs // { zeromq3 = pkgs.zeromq4; };
      self = customPythonPackages;
    });
  in customPythonPackages.pyzmq;

in pythonPackages.buildPythonApplication rec {
  inherit webpy-custom flup-dev;
  version = "0.3a2.dev0";
  name = "inginious-${version}";

  propagatedBuildInputs = with pythonPackages; [
    docker
    docutils
    pymongo
    pyyaml
    webpy-custom
    watchdog
    msgpack
    pyzmq-with-zeromq4
    sh

    flup-dev

    tidylib
    sphinx_rtd_theme
    pygments

    #"pylti>=0.4.1", # TODO re-add me once PyLTI PR is accepted
    # These are the dependencies for the in-tree checkout of pylti.
    oauth2 httplib2 six

    #requests2 # not needed anymore ?
  ];

  buildInputs = with pythonPackages; [ selenium nose virtual-display ];

  doCheck = false;

  /* Hydra fix exists only on github for now.
  src = pkgs.fetchurl {
    url = "mirror://pypi/I/INGInious/INGInious-${version}.tar.gz";
  };
  */
  src = pkgs.fetchFromGitHub {
    owner = "UCL-INGI";
    repo = "INGInious";
    rev = "bcb49673eb2a757b4225a8255c8edd928fa30b33";
    sha256 = "1jq4ww0bfcchpibpznfaa282vk6fwwnqwjfl6ar7q5sc3mf8vlxx";
  };

  patchPhase = ''
    sed -i 's/)).read()/), encoding="utf-8").read()/' setup.py
    cat setup.py
  '';

  # Only patch shebangs in /bin, other scripts are run within docker
  # containers and will fail if patched.
  dontPatchShebangs = true;
  preFixup = ''
    patchShebangs $prefix/bin
  '';

  meta = {
    description = "An intelligent grader that allows secured and automated testing of code made by students";
    homepage = "https://github.com/UCL-INGI/INGInious";
    license = licenses.agpl3;
    maintainers = with maintainers; [ layus ];
  };
}
