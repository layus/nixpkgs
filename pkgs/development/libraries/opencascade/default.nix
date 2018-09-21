{stdenv, fetchurl, libGLU_combined, tcl, tk, file, libXmu, cmake, libtool, qt4,
ftgl, freetype}:

stdenv.mkDerivation rec {
  version = "0.18.3";
  name = "opencascade-oce-${version}";
  src = fetchurl {
    url = "https://github.com/tpaviot/oce/archive/OCE-${version}.tar.gz";
    sha256 = "0v4ny0qhr5hiialb2ss25bllfnd6j4g7mfxnqfmr1xsjpykxcly5";
  };

  buildInputs = [ libGLU_combined tcl tk file libXmu libtool qt4 ftgl freetype cmake ];

  # Fix for glibc 2.26
  #postPatch = ''
  #  sed -i -e 's/^\( *#include <\)x\(locale.h>\)//' \
  #    src/Standard/Standard_CLocaleSentry.hxx
  #'';

  preConfigure = ''
    cmakeFlags="$cmakeFlags -DOCE_INSTALL_PREFIX=$out"
  '';

  # https://bugs.freedesktop.org/show_bug.cgi?id=83631
  #NIX_CFLAGS_COMPILE = "-DGLX_GLXEXT_LEGACY";

  enableParallelBuilding = true;

  meta = {
    description = "Open CASCADE Technology, libraries for 3D modeling and numerical simulation";
    homepage = http://www.opencascade.org/;
    maintainers = with stdenv.lib.maintainers; [viric];
    platforms = with stdenv.lib.platforms; linux;
  };
}
