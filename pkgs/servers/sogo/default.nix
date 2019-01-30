{ stdenv, fetchurl
, gnustep
, clang
, llvmPackages
, libxml2
, openssl
, openldap
, postgresql
, libmemcached
, mysql
, curl
}:

rec {
  SOPE = gnustep.gsmakeDerivation rec {
    pname = "SOPE";
    version = "4.0.5";
    name = "${pname}-${version}";

    src = fetchurl {
      url = "https://sogo.nu/files/downloads/SOGo/Sources/${name}.tar.gz";
      sha256 = "1xmzipkkpqjh1lm2ylhhvp8wj32dd5hdb2hmwawpkyqnzp283xpn";
    };

    patches = [ ./wod.patch ];

    nativeBuildInputs = [ gnustep.make ];
    buildInputs = [
      gnustep.base gnustep.libobjc
      libxml2 openssl openldap postgresql libmemcached curl.dev mysql
    ];

    prePatch = ''
      sed -i configure \
        -e "/^[[:space:]]*exit 1 *$/d" \
        -e 's/grep GNUSTEP/grep "^GNUSTEP"/'
      sed -i sope-appserver/NGObjWeb/GNUmakefile.postamble \
        -e 's#$(DESTDIR)/$(GNUSTEP_MAKEFILES)#$(DESTDIR_GNUSTEP_MAKEFILES)#g'
    '';

    preBuild = ''
      export NIX_GNUSTEP_MAKEFILES_ADDITIONAL=$(echo $NIX_GNUSTEP_MAKEFILES_ADDITIONAL | tr  "\n" | awk '!_[$0]++' | tr "\n" " ")
    '';

    makeFlages = [ "VERBOSE=1" "-DGNUSTEP=1" ];

    #configureFlags = [ "--with-gnustep" ];
    #enableParallelBuilding = true;

    hardeningDisable = [ "fortify" ];


  };

  SOGo = llvmPackages.stdenv.mkDerivation rec {
    pname = "SOGo";
    version = "4.0.5";
    name = "${pname}-${version}";

    src = fetchurl {
      url = "https://sogo.nu/files/downloads/SOGo/Sources/${name}.tar.gz";
      sha256 = "0q4hxpk0szcghdzkysjgl73qm698pmrfdz72hbfrg6kikjsr2hpn";
    };

    nativeBuildInputs = [ gnustep.make ];
    buildInputs = [
      SOPE
      clang
      gnustep.base gnustep.libobjc
      libxml2 openssl openldap postgresql libmemcached curl.dev
    ];

    patches = [ ./ssl_error.patch ];

    prePatch = ''
      export GNUSTEP_LOCAL_ROOT=$out
      #sed -i configure \
      #  -e "/^[[:space:]]*exit 1 *$/d" \
      #  -e 's/grep GNUSTEP/grep "^GNUSTEP"/'
      sed -i -e '/wobundle.make/ s#$(GNUSTEP_MAKEFILES)#${SOPE}/share/GNUstep/Makefiles#' \
        SoObjects/Mailer/GNUmakefile \
        SoObjects/Appointments/GNUmakefile
    '';

    preConfigure = ''
    '';

    preBuild = ''
      echo $NIX_GNUSTEP_MAKEFILES_ADDITIONAL
      export NIX_GNUSTEP_MAKEFILES_ADDITIONAL=$(echo $NIX_GNUSTEP_MAKEFILES_ADDITIONAL | tr " " "\n" | awk '!_[$0]++' | tr "\n" " ")
      echo $NIX_GNUSTEP_MAKEFILES_ADDITIONAL
      echo GNUSTEP_SYSTEM_LIBRARIES : $GNUSTEP_SYSTEM_LIBRARIES
      export GNUSTEP_INSTALLATION_DIR=$out
    '';

    makeFlags = [
      "VERBOSE=1"
      "SOGO_SYSLIBDIR=$(out)/lib"
      "GNUSTEP_SYSTEM_LIBRARIES=$(out)/lib/"
      "GNUSTEP_INSTALLATION_DIR=$(out)"
    ];


    dontPatchELF = true;
    enableParallelBuilding = true;

    hardeningDisable = [ "fortify" ];
  };
}
