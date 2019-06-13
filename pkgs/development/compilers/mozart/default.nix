{ stdenv, fetchFromGitHub, fetchurl
, cmake, makeWrapper, unzip
, boost, gmp, emacs25-nox, emacs, jre_headless, tcl, tk
}:

stdenv.mkDerivation rec {
  pname = "mozart2";
  version = "2.0.1";

  src = fetchurl {
    url = "https://github.com/mozart/${pname}/releases/download/v${version}/${pname}-${version}-Source.zip";
    sha256 = "1mad9z5yzzix87cdb05lmif3960vngh180s2mb66cj5gwh5h9dll";
  };

  # Avoid building the bootcompiler, as it is a complex sbt project.
  bootcompiler = fetchurl {
    url = "https://github.com/layus/mozart2/releases/download/v2.0.0-beta.1/bootcompiler.jar";
    sha256 = "1hgh1a8hgzgr6781as4c4rc52m2wbazdlw3646s57c719g5xphjz";
  };

  postConfigure = ''
    cp ${bootcompiler} bootcompiler/bootcompiler.jar
  '';

  nativeBuildInputs = [ cmake makeWrapper unzip ];

  cmakeFlags = [
    "-DBoost_USE_STATIC_LIBS=OFF"
    "-DMOZART_BOOST_USE_STATIC_LIBS=OFF"
  ];

  fixupPhase = ''
      wrapProgram $out/bin/oz --set OZEMACS ${emacs}/bin/emacs
  '';

  buildInputs = [
    boost
    gmp
    emacs25-nox
    jre_headless
    tcl
    tk
  ];
}





