{
  stdenv,
  automake, autoconf, libtool, pkgconfig,
  cups, glib, gnome2, atk, libxml2, popt, ghostscript,
  cndrvcups-common
}:

stdenv.mkDerivation rec {
  name = "${pname}-${version}";
  pname = "cndrvcups-capt";
  version = "2.71";

  src = ./cndrvcups-capt-2.71;

  #TODO: prune unused dependencies
  buildInputs = [
    automake autoconf libtool pkgconfig
    cups
    glib
    gnome2.libglade
    gnome2.gtk
    atk
    libxml2.dev
    popt
    ghostscript
    cndrvcups-common
  ];

  # install directions based on arch PKGBUILD file
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=capt-src

  configurePhase = ''
    set -xe

    for _dir in driver ppd backend pstocapt pstocapt2 pstocapt3
    do
        pushd $_dir
          autoreconf -fi
          ./autogen.sh --prefix=$out --enable-progpath=$out/bin --disable-static
        popd
    done

    pushd statusui
      autoreconf -fi
      CPPFLAGS=-I${libxml2.dev}/include/libxml2 \
        LIBS='-lpthread -lgdk-x11-2.0 -lgobject-2.0 -lglib-2.0 -latk-1.0 -lgdk_pixbuf-2.0' \
        ./autogen.sh --prefix=$out --disable-static
    popd

    pushd cngplp
      autoreconf -fi
      ./autogen.sh --prefix=$out --libdir=$out/lib
    popd

    pushd cngplp/files
      autoreconf -fi
      ./autogen.sh
    popd
  '';

  buildPhase = ''
    make
  '';

  installPhase = ''
    mkdir -p $out

    for _dir in driver ppd backend pstocapt pstocapt2 pstocapt3 statusui cngplp
    do
        pushd $_dir
          make install DESTDIR=$out
        popd
    done

    ##HACK: `make install` install files to wrong directory
    cp -rv $out/$out/* $out
    rm -r $out/nix

    install -dm755 $out/lib
    install -c libs/libcaptfilter.so.1.0.0  $out/lib
    install -c libs/libcaiocaptnet.so.1.0.0 $out/lib
    install -c libs/libcncaptnpm.so.2.0.1   $out/lib
    install -c -m 755 libs/libcnaccm.so.1.0 $out/lib

    pushd $out/lib
      ln -s libcaptfilter.so.1.0.0 libcaptfilter.so.1
      ln -s libcaptfilter.so.1.0.0 libcaptfilter.so
      ln -s libcaiocaptnet.so.1.0.0 libcaiocaptnet.so.1
      ln -s libcaiocaptnet.so.1.0.0 libcaiocaptnet.so
      ln -s libcncaptnpm.so.2.0.1 libcncaptnpm.so.2
      ln -s libcncaptnpm.so.2.0.1 libcncaptnpm.so
      ln -s libcnaccm.so.1.0 libcnaccm.so.1
      ln -s libcnaccm.so.1.0 libcnaccm.so
    popd

    install -dm755 $out/bin
    install -c libs/captdrv            $out/bin
    install -c libs/captfilter         $out/bin
    install -c libs/captmon/captmon    $out/bin
    install -c libs/captmon2/captmon2  $out/bin
    install -c libs/captemon/captmon*  $out/bin

    ##FIXME: currently install x64 only, find the way to choose
    install -c libs64/ccpd       $out/bin
    install -c libs64/ccpdadmin  $out/bin
    # install -c libs/ccpd       $out/bin
    # install -c libs/ccpdadmin  $out/bin

    install -dm755 $out/etc
    install -c samples/ccpd.conf  $out/etc

    install -dm755 $out/share/ccpd
    install -c libs/ccpddata/CNA*L.BIN    $out/share/ccpd
    install -c libs/ccpddata/CNA*LS.BIN   $out/share/ccpd
    install -c libs/ccpddata/cnab6cl.bin  $out/share/ccpd
    install -c libs/captemon/CNAC*.BIN    $out/share/ccpd

    install -dm755 $out/share/captfilter
    install -c libs/CnA*INK.DAT $out/share/captfilter

    install -dm755 $out/share/captmon
    install -c libs/captmon/msgtable.xml    $out/share/captmon
    install -dm755 $out/share/captmon2
    install -c libs/captmon2/msgtable2.xml  $out/share/captmon2
    install -dm755 $out/share/captemon
    install -c libs/captemon/msgtablelbp*   $out/share/captemon
    install -c libs/captemon/msgtablecn*    $out/share/captemon
    install -dm755 $out/share/caepcm
    install -c -m 644 data/C*   $out/share/caepcm
    install -dm755 $out/share/doc/capt-src
    install -c -m 644 *capt*.txt $out/share/doc/capt-src
  '';

  meta = with stdenv.lib; {
    description = "Canon CAPT driver";
    longDescription = ''
      Canon CAPT driver
    '';
  };
}
