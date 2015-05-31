{ withKDE ? true,
stdenv, fetchurl, qt, kdelibs, gettext, pkgconfig, poppler_qt4, auctex }:

assert withKDE -> kdelibs != null;
assert ! withKDE -> pkgconfig != null;

let 
  version = "0.10";
  commonBuildInputs = [ gettext qt4 poppler_qt4 auctex ];

  qtikz = {
    name = "qtikz-${version}";

    conf = ''
      # installation prefix:
      #PREFIX = ""

      # install desktop file here (*nix only):
      DESKTOPDIR = ''$''${PREFIX}/share/applications

      # install mimetype here:
      MIMEDIR = ''$''${PREFIX}/share/mime/packages

      CONFIG -= debug
      CONFIG += release

      # qmake command:
      QMAKECOMMAND = qmake
      # lrelease command:
      LRELEASECOMMAND = lrelease
      # qcollectiongenerator command:
      #QCOLLECTIONGENERATORCOMMAND = qcollectiongenerator

      # TikZ documentation default file path:
      TIKZ_DOCUMENTATION_DEFAULT = ''$''${PREFIX}/share/doc/texmf/pgf/pgfmanual.pdf.gz
    '';

    patchPhase = ''
      echo "$conf" > conf.pri
    '';

    configurePhase = ''
      qmake PREFIX="$out" ./qtikz.pro
    ''; 
    
    buildInputs = commonBuildInputs ++ [ pkgconfig ];
  };

  ktikz = {
    name = "ktikz-${version}";
    buildInputs = commonBuildInputs ++ [ kdelibs ];
  };

  common = {
    inherit version;
    src = fetchurl {
      url = "http://www.hackenberger.at/ktikz/ktikz_${version}.tar.gz";
      md5 = "e8f0826cba2447250bcdcd389a71a2ac";
    };

    meta = with stdenv.lib; {
      description = "Editor for the TikZ language";
      license = licenses.gpl2;
      platforms = platforms.linux;
      maintainers = [ maintainers.layus ];

      # This packages depends on auctex being compiled with preview.sty.
      # This is not yet possible as we wait for a unified latex framework.
      broken = true;
    };
  };

in stdenv.mkDerivation (
  if withKDE
  then common // ktikz
  else common // qtikz
)

