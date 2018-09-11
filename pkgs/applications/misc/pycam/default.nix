{ stdenv, python3Packages, fetchurl, fetchFromGitHub, wrapGAppsHook
, gnome2, pkgconfig, xorg, libGLU
, gtk3, gobjectIntrospection,
}:

let
  pythonPackages = python3Packages;

in pythonPackages.buildPythonApplication rec {
  pname = "pycam-unstable";
  version = "v0.6.2-495-g433c1cf";

  src = fetchFromGitHub {
    owner = "SebKuzminsky";
    repo = "pycam";
    rev = "433c1cf3f4e6ee5b24dab00489eb21916af54f04";
    sha256 = "1rhcg120zr5l7bcc4pnh0njqkv7jawr9skg934nizh6bcspcqdj8";
  };

  nativeBuildInputs = [
    pythonPackages.pytest
    wrapGAppsHook
  ];

  buildInputs = [
    gtk3 gobjectIntrospection
  ];

  propagatedBuildInputs = with pythonPackages; [
    pygobject3
    pyyaml
    svg-path
    pyopengl
  ];

  makeWrapperArgs = [
    "--set" "PYCAM_DATA_DIR" "$out/share/pycam"
    #"--prefix" "GI_TYPELIB_PATH" ":" "$GI_TYPELIB_PATH"
  ];

  doCheck = false;

  meta = with stdenv.lib; {
    description = "Bindings for scrypt key derivation function library";
    homepage = https://pypi.python.org/pypi/scrypt;
    maintainers = with maintainers; [ asymmetric ];
    license = licenses.bsd2;
  };
}
