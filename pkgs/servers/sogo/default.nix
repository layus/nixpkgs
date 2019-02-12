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
      export NIX_GNUSTEP_MAKEFILES_ADDITIONAL=$(echo $NIX_GNUSTEP_MAKEFILES_ADDITIONAL | tr " " "\n" | awk '!_[$0]++' | tr "\n" " ")
    '';

    # FIXME: Still needed with --with-gnustep ?
    postInstall = ''
      mkdir -p $out/lib/GNUstep
      ln -s $out/lib/sope-* $out/lib/GNUstep
    '';

    configureFlags = [ "--with-gnustep" ];

    hardeningDisable = [ "fortify" ];
  };

  SOGo = gnustep.gsmakeDerivation rec {
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

    preConfigure = ''
      export "''${installFlagsArray[@]}"
    '';

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

    preBuild = ''
      export NIX_GNUSTEP_MAKEFILES_ADDITIONAL=$(echo $NIX_GNUSTEP_MAKEFILES_ADDITIONAL | tr " " "\n" | awk '!_[$0]++' | tr "\n" " ")
      makeFlagsArray=("''${installFlagsArray[@]}")
    '';

    # FIXME: This is part of gsmakederivation, but it happens before /sbin gets
    # moved to /bin, and thus never wraps /sbin stuff.
    postFixup = ''
      for i in $out/bin/*; do
        echo "wrapping $(basename $i)"
        wrapGSMake "$i" "$out/share/.GNUstep.conf"
      done
    '';

    enableParallelBuilding = true;

    hardeningDisable = [ "fortify" ];
  };
}
