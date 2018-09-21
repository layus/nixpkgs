{ stdenv, lib, fetchurl
, pkgconfig, autoconf, automake
, udev, libmodbus, libusb, glib, gtk2, procps, kmod, utillinux, psmisc, man
, python, tcl, tk, bwidget, xorg, fontconfig, tcllib, tclx, libXaw
, readline, boost, libGL, libGLU, intltool, makeWrapper
}:

let
  tkimg = stdenv.mkDerivation rec {
    name = "tkImg-${version}";
    version_maj = "1.4";
    version = "${version_maj}.7";

    src = fetchurl {
      url = "mirror://sourceforge/tkimg/tkimg/${version_maj}/tkimg%20${version}/Img-Source-${version}.tar.gz";
      sha256 = "1vmj5b8v8fz5831jfnjbrh5q3mmzp3whrxmb09l6zwz12c4kwlay";
    };

    TCLLIBPATH="${tcllib}/lib/tcllib${tcllib.version}";
    configureFlags = [
      "--with-tcl=${tcl}/lib" "--with-tk=${tk}/lib"
      "--with-tkinclude=${tk.dev}/include"
      "--exec-prefix=$(out)"
      "--enable-64bit" "--enable-threads"
    ];

    buildInputs = [ xorg.libX11 fontconfig tcl tk tcllib ];

  #makeFlags = [ "INSTALL_ROOT=$(out)" ];
  };

  boost_python = boost.override { enablePython = true; python = python; };

  binpath = lib.makeBinPath [ udev procps kmod utillinux psmisc python tcl tk readline ];

in python.pkgs.buildPythonApplication rec {
  name = "linuxcnc-${version}";
  version = "2.7.14";
  format = "other";

  src = fetchurl {
    url = "https://github.com/LinuxCNC/linuxcnc/archive/v${version}.tar.gz";
    sha256 = "0c1b413ahxy3n33371x7v9r89dp78dllzi31plwwnhl64h315l8y";
  };

  buildInputs = [
    pkgconfig autoconf automake udev libmodbus libusb glib gtk2 procps kmod
    utillinux psmisc man python tcl tk bwidget libXaw tclx readline
    boost_python libGL libGLU intltool makeWrapper
  ];

  propagatedBuildInputs = with python.pkgs; [
    pygtk pyopengl
  ];

  patches = [
    # Fix for libmodbus >= 3.1.2
    (fetchurl {
      url = "https://github.com/LinuxCNC/linuxcnc/pull/106.diff";
      sha256 = "1nff376gjylzaq1q3j1m18j5f8cibll7jrkr8sy72wswab3di6nk";
    })
  ];

  postPatch = ''
    patchShebangs .
    sed -e '/=install/ s/ -o root//' \
        -e '/=install/ s/ -m 4755/ -m 0755/' \
        -e 's,$(DESTDIR)/etc/X11,$(DESTDIR)$(prefix)/etc/X11,g' \
        -i src/Makefile
    sed -e '/initd_dir =/ s,/etc/init.d,''${prefix}&,' \
        -i src/Makefile.inc.in
  '';

  TCLLIBPATH = "${bwidget}/lib/bwidget${bwidget.version} ${tkimg}/lib/Img${tkimg.version} ${tclx}/lib/tclx${tclx.version}";

  preConfigure = ''
    cd src
    ./autogen.sh
    echo $TCLLIBPATH
    export TCLLIBPATH=$TCLLIBPATH
  '';

  configureFlags = [
    "--with-realtime=uspace"
    "--with-tclConfig=${tcl}/lib/tclConfig.sh"
    "--with-tkConfig=${tk}/lib/tkConfig.sh"
    "--enable-non-distributable=yes"
    "--with-boost-python=boost_python27"
    "--prefix=${builtins.placeholder "out"}" "--exec-prefix=${builtins.placeholder "out"}"
    "--with-locale-dir=$(out)/share/locale"
  ];

  makeFlags = [ "DESTDIR=" "SITEPY=${builtins.placeholder "out"}/${python.sitePackages}" ];

  makeWrapperArgs = [
    "--prefix" "PATH" ":" ''${binpath}''
    "--set" "TCLLIBPATH" ''${TCLLIBPATH}''
  ];

  # Build is non-redistributable due to license conflict.
  # remove --enable-non-distributable above and re-run to get more info
  preferLocalBuild = true;

  inherit tkimg boost_python;
}
