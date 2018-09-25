{ stdenv
, bison
, fetchurl
, ffmpeg
, gcc
, gperf
, gradle
, gstreamer
, gtk2
, jdk
, mercurial
, pkgconfig
, python3
, qt5
, ruby
#, webkitgtk2
, javaPackages
, xorg
}:

let

  # https://anonscm.debian.org/cgit/pkg-java/openjfx.git/tree/debian/patches?id=7402e3f
  gccCompatibilityPatch = ./17-gcc-compatibility.patch;

in stdenv.mkDerivation rec {
  name = "openjfx-${repover}";

  update = "202";
  build = "00";
  repover = "8u${update}-b${build}";
  src = fetchurl {
    url = "http://hg.openjdk.java.net/openjfx/8u/rt/archive/${repover}.tar.gz";
    sha256 = "1hf04vygl61qldnwzxlj4rmd5k8j7a5qy3w7fqm14ycl36sqv97m";
  };

  cache = stdenv.mkDerivation {
    name = "gradle-cache";
    inherit src buildInputs;

    resolver = ''

      task resolveDependencies {
          doLast {
              project.rootProject.allprojects.each { subProject ->
                  subProject.buildscript.configurations.each { configuration ->
                      resolveConfiguration(configuration)
                  }
                  subProject.configurations.each { configuration ->
                      resolveConfiguration(configuration)
                  }
              }
          }
      }

      void resolveConfiguration(configuration) {
          if (configuration.isCanBeResolved()) {
              configuration.resolve()
          }
      }
    '';

    patchPhase = ''
      echo "$resolver" >> build.gradle
    '';

    buildPhase = ''
      gradle --no-daemon -g $PWD/.gradle-cache resolveDependencies
    '';

    installPhase = ''
      mkdir -p $out
      cp -r .gradle-cache/caches/modules-2 $out
    '';

    outputHash = "143gpd83vkpk106ha1gfs88wwdyi128r749k53kiz5zawyznh8iy";
    outputHashAlgo = "sha256";
    outputHashMode = "recursive";
  };


  buildInputs = [
    bison
    ffmpeg
    gcc
    gperf
    gradle
    gstreamer
    gtk2
    jdk
    mercurial
    pkgconfig
    python3
    qt5.qtbase
    ruby
    #webkitgtk2
    xorg.libXtst
  ];

  patchPhase = ''
    patch -p1 < ${gccCompatibilityPatch}
  '';

  buildPhase = ''
    GRADLE_USER_HOME="$(mktemp -d)" gradle sdk --offline --scan --no-daemon
  '';

  installPhase = ''
    cp -rv build/sdk $out
  '';

  meta = {
    description = "The next generation Java client toolkit.";
    homepage = http://openjdk.java.net/projects/openjfx;
    license = stdenv.lib.licenses.gpl2;
    meta.platforms = stdenv.lib.platforms.linux;
  };
}
