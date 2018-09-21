{ stdenv, fetchurl
, scons, openssl, qt5, v8, pkgconfig
}:

stdenv.mkDerivation rec {
  name = "CAMotics-${version}";
  version = "1.1.1";

  srcs = [
    (fetchurl {
      url = "https://github.com/CauldronDevelopmentLLC/CAMotics/archive/1.1.1-release.tar.gz";
      sha256 = "1zn01jwpc6w3svrg7kpm4cjqww4d18cy2zc7yg27hizlb5wcxgkl";
    })

    (fetchurl {
      url = "https://github.com/CauldronDevelopmentLLC/cbang/archive/1.2.0.tar.gz";
      sha256 = "1k8dqbfywcqkkah2ww0rd8n48ck10cx03c0jy2ax06njxj6hbdyr";
    })
  ];

  sourceRoot = ".";

  buildInputs = [
    scons openssl qt5.qttools qt5.qtwebsockets v8 pkgconfig
  ];

  V8_HOME="${v8}";

  buildPhase = ''
    # Build C!
    pushd cbang-1.2.0
      scons
      export CBANG_HOME=$PWD
    popd

    # Build CAMotics
    pushd CAMotics-1.1.1-release
      scons --prefix=$out install
    popd
  '';
}
