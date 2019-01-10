{ stdenv, fetchurl
, gnustep
#, gcc
#, gcc-objc
, clang
, llvmPackages
, libxml2
, openssl
, openldap
, postgresql
, libmemcached
, curl
}:

rec {
  SOPE = llvmPackages.stdenv.mkDerivation rec {
    pname = "SOPE";
    version = "4.0.4";
    name = "${pname}-${version}";

    src = fetchurl {
      url = "https://sogo.nu/files/downloads/SOGo/Sources/${name}.tar.gz";
      sha256 = "1yyjfa8kq1xzarx87n5sd6hbkd2nw1s7dw72jkvd61nmiqivg0nq";
    };

    nativeBuildInputs = [ gnustep.make ];
    buildInputs = [
      #gcc
      clang
      gnustep.base gnustep.libobjc
      libxml2 openssl openldap postgresql libmemcached curl.dev
    ];

    prePatch = ''
      sed -i configure \
        -e "/^[[:space:]]*exit 1 *$/d" \
        -e 's/grep GNUSTEP/grep "^GNUSTEP"/'
      sed -i sope-appserver/NGObjWeb/GNUmakefile.postamble \
        -e 's#$(DESTDIR)/$(GNUSTEP_MAKEFILES)#$(DESTDIR_GNUSTEP_MAKEFILES)#g'
    '';

    preBuild = ''
      export NIX_GNUSTEP_MAKEFILES_ADDITIONAL=$(echo $NIX_GNUSTEP_MAKEFILES_ADDITIONAL | tr " " "\n" | awk '!_[$0]++' | tr "\n" " ")
    '';

    #configureFlags = [ "--with-gnustep" ];

    hardeningDisable = [ "fortify" ];


  };

  SOGo = llvmPackages.stdenv.mkDerivation rec {
    pname = "SOGo";
    version = "4.0.4";
    name = "${pname}-${version}";

    src = fetchurl {
      url = "https://sogo.nu/files/downloads/SOGo/Sources/${name}.tar.gz";
      sha256 = "0mk2wb0kh01n3m79c5pp8llc873sk2v7s4i09n5chi02h58bfglf";
    };

    nativeBuildInputs = [ gnustep.make ];
    buildInputs = [
      #gcc
      SOPE
      clang
      gnustep.base gnustep.libobjc
      libxml2 openssl openldap postgresql libmemcached curl.dev
    ];

    patches = [ ./ssl_error.patch ];

    prePatch = ''
      sed -i configure \
        -e "/^[[:space:]]*exit 1 *$/d" \
        -e 's/grep GNUSTEP/grep "^GNUSTEP"/'
      sed -i -e '/wobundle.make/ s#$(GNUSTEP_MAKEFILES)#${SOPE}/share/GNUstep/Makefiles#' \
        SoObjects/Mailer/GNUmakefile \
        SoObjects/Appointments/GNUmakefile
    '';

    preBuild = ''
      echo $NIX_GNUSTEP_MAKEFILES_ADDITIONAL
      export NIX_GNUSTEP_MAKEFILES_ADDITIONAL=$(echo $NIX_GNUSTEP_MAKEFILES_ADDITIONAL | tr " " "\n" | awk '!_[$0]++' | tr "\n" " ")
      echo $NIX_GNUSTEP_MAKEFILES_ADDITIONAL
      '';

    hardeningDisable = [ "fortify" ];
  };
}
