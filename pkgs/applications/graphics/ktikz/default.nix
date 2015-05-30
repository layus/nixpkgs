{ stdenv, fetchurl, kdelibs, gettext, poppler_qt4, auctex }:

stdenv.mkDerivation rec {
  name = "ktikz-${version}";
  version = "0.10";

  src = fetchurl {
    url = "http://www.hackenberger.at/ktikz/ktikz_${version}.tar.gz";
    md5 = "e8f0826cba2447250bcdcd389a71a2ac";
  };

  buildInputs = [ gettext kdelibs poppler_qt4 auctex ];

  meta = with stdenv.lib; {
    description = "Editor for the TikZ language";
    license = licenses.gpl2;
    platforms = platforms.linux;
    maintainers = [ maintainers.layus ];

    # This packages depends on auctex being compiled with preview.sty.
    # This is not yet possible as we wait for a unified latex framework.
    broken = true;
  };
}


