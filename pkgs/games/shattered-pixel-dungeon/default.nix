{ stdenv, fetchurl, gradle_4_10, perl, makeWrapper, jre, makeDesktopItem, writeText, jdk, gdx, lwjgl, openal}:

let
  version = "0.7.1d";
  name = "shattered-pixel-dungeon-gdx-${version}";

  src = fetchurl {
    url    = "https://github.com/00-Evan/shattered-pixel-dungeon-gdx/archive/v${version}.tar.gz";
    sha256 = "1hfpys6s68rd4vpn76h6l6cilcwbqsjv38jpjx8d5jiqgd3763zd";
  };

  deps = stdenv.mkDerivation {
    name = "${name}-deps";
    inherit src;
    nativeBuildInputs = [ gradle_4_10 perl ];

    buildPhase = ''
      export GRADLE_USER_HOME=$(mktemp -d);
      gradle --no-daemon desktop:run
    '';

    # Mavenize dependency paths
    # e.g. org.codehaus.groovy/groovy/2.4.0/{hash}/groovy-2.4.0.jar -> org/codehaus/groovy/groovy/2.4.0/groovy-2.4.0.jar
    installPhase = ''
      find $GRADLE_USER_HOME/caches/modules-2 -type f -regex '.*\.\(jar\|pom\)' \
        | perl -pe 's#(.*/([^/]+)/([^/]+)/([^/]+)/[0-9a-f]{30,40}/([^/\s]+))$# ($x = $2) =~ tr|\.|/|; "install -Dm444 $1 \$out/$x/$3/$4/$5" #e' \
        | sh
    '';

    outputHashAlgo = "sha256";
    outputHashMode = "recursive";
    outputHash = "0ljzx8xbmrfycr67ck8hjsyznk6mfnl03iw3l8jw34bfbajvl5i8";
  };

  # Point to our local deps repo
  gradleInit = writeText "init.gradle" ''
    logger.lifecycle 'Replacing Maven repositories with ${deps}...'

    gradle.projectsLoaded {
      rootProject.allprojects {
        buildscript {
          repositories {
            clear()
            maven { url '${deps}' }
          }
        }
        repositories {
          clear()
          maven { url '${deps}' }
        }
      }
    }
  '';

  desktopItem = launcher: makeDesktopItem {
    name = "shattered-pixel-dungeon-gdx";
    exec = "${launcher} %F";
    icon = "shattered-pixel-dungeon";
    comment = "Shattered Pixel Dungeon";
    desktopName = "Shattered Pixel Dungeon";
    genericName = "";
    mimeType = "application/x-java-archive;application/x-java";
    categories = "Game;";
  };

in stdenv.mkDerivation rec {
  inherit name version src;

  nativeBuildInputs = [ gradle_4_10 perl makeWrapper gdx lwjgl ];

  patches = [ ./preload.patch ];
  postPatch = ''
    substituteInPlace desktop/src/com/watabou/pd/desktop/DesktopLauncher.java \
      --subst-var-by gdx ${gdx}/lib/libgdx64.so \
      --subst-var-by lwjgl ${lwjgl}/lib/liblwjgl.so \
      --subst-var-by openal ${openal}/lib/libopenal.so
  '';

  buildPhase = ''
    export GRADLE_USER_HOME=$(mktemp -d)
    gradle --offline --no-daemon --info --init-script ${gradleInit} desktop:dist
  '';

  installPhase = let
    jar = "$out/share/${name}.jar";
  in ''
    mkdir -p $out/bin $out/share/{,icons/hicolor/128x128/apps}
    cp desktop/build/libs/desktop-${version}.jar ${jar}
    cp android/res/drawable-xxxhdpi/ic_launcher.png $out/share/icons/hicolor/128x128/apps/shattered-pixel-dungeon.png

    cat > $out/bin/shattered-pixel-dungeon <<EOF
    #!${stdenv.shell}
    export JAVA_HOME=${jre}
    ${jre}/bin/java -jar ${jar} $@
    EOF
    chmod +x $out/bin/shattered-pixel-dungeon

    ${(desktopItem "$out/bin/shattered-pixel-dungeon").buildCommand}
  '';

  dontStrip = true;

  inherit deps;

  meta = with stdenv.lib; {
    description = "GDX port of Shattered Pixel Dungeon the awesome fork of Pixel Dungeon";
    homepage    = "https://github.com/00-Evan/shattered-pixel-dungeon-gdx";
    license     = licenses.gpl3;
    platforms   = platforms.unix;
    maintainers = [ maintainers.layus ];
    passthru = { inherit deps; };
  };
}
