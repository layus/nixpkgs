{ stdenv, fetchurl, python2Packages
, withSpellCheck ? true, hunspellWithDicts
}:

#
# Zim has many plugins depending on external programs and commands.
# For most of them, it is sufficient to have the executable in the PATH
# For example, the VCS plugin finds git/bzr/hg if they are installed.
#
# For other plugins, we need special python packages that are not found when
# installed in the path, like with gtkspell and gtkspellcheck.
#
# TODO: Declare configuration options for the following optional dependencies:
#  -  File stores: hg, git, bzr
#  -  Included plugins depenencies: dot, ditaa, dia, any other?
#  -  pyxdg: Need to make it work first (see setupPyInstallFlags).
#

python2Packages.buildPythonApplication rec {
  name = "zim-${version}";
  version = "0.68";

  src = fetchurl {
    url = "http://zim-wiki.org/downloads/${name}.tar.gz";
    sha256 = "05fzb24a2s3pm89zb6gwa48wb925an5i652klx8yk9pn23h1h5fr";
  };

  propagatedBuildInputs = with python2Packages; [
    pyGtkGlade pyxdg pygobject2
  ] ++ lib.optional (withSpellCheck) [
    pygtkspellcheck
  ];

  preBuild = ''
    export HOME=$TMP

    sed -i '/zim_install_class,/d' setup.py
  '';


  preFixup = ''
    export makeWrapperArgs="--prefix XDG_DATA_DIRS : $out/share --argv0 $out/bin/.zim-wrapped"
  '';

  # RuntimeError: could not create GtkClipboard object
  doCheck = false;

  checkPhase = ''
    python test.py
  '';


  meta = with stdenv.lib; {
    description = "A desktop wiki";
    homepage = http://zim-wiki.org;
    license = licenses.gpl2Plus;
    maintainers = with maintainers; [ pSub ];
  };
}
