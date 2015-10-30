{ fetchurl, stdenv
, gtk2, libxml2, libofx, intltool, pkgconfig, cunit, openssl, goffice
}:

stdenv.mkDerivation rec {
  name = "grisbi-1.0.0";

  src = fetchurl {
    url = "mirror://sourceforge/grisbi/${name}.tar.bz2";
    sha256 = "0m9cz5q5cj3w7zanh5f77ayklhxcgchdjakh33ci8s36fxkx48wa";
  };

  buildInputs = [ gtk2 libxml2 libofx intltool pkgconfig cunit openssl goffice ];

  configureFlags = "--enable-goffice";

  #postInstall = '' '';

  # The following settings fix failures in the test suite. It's not required otherwise.
  #NIX_LDFLAGS = "-rpath=${guile}/lib -rpath=${glib}/lib";
  #preCheck = "export GNC_DOT_DIR=$PWD/dot-gnucash";
  #doCheck = true;

  enableParallelBuilding = true;

  meta = {
    description = "Personal financial management program with a reasonable set of homefinance features";

    longDescription = ''
        Grisbi est un logiciel libre de comptabilité personnelle, développé en
      Langage C avec le support GTK2, originellement pour la plate-forme
      GNU/Linux. Il y a maintenant un portage sous Windows, Mac OSX, FreeBSD,
      des paquetages pour différentes distributions Linux, et d’autres
      possibilités à découvrir sur le site de Grisbi ou celui de Sourceforge.
        Le principe de base est de vous permettre de classer de façon simple et
      intuitive vos opérations financières, quelles qu’elles soient, afin de
      pouvoir les exploiter au mieux en fonction de vos besoins.
        Grisbi a pris le parti de la simplicité et de l’efficacité pour un
      usage de base, sans toutefois exclure la sophistication nécessaire à un
      usage plus avancé. Les fonctionnalités futures tenteront toujours de
      respecter ces critères.
    '';

    license = stdenv.lib.licenses.gpl2;

    homepage = http://www.grisbi.org/;

    maintainers = with stdenv.lib.maintainers; [ layus ];
    platforms = stdenv.lib.platforms.gnu;
  };
}
