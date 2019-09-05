{ stdenv
, runCommand
, lib
, coreutils
, callPackage
, tree
, buildFHSUserEnv
, makeWrapper
, writeShellScriptBin
}:

let
  common = callPackage ./common.nix {};
  capt = callPackage ./capt.nix { cndrvcups-common = common;};
  doc = callPackage ./doc.nix {};
  fhs-runner = writeShellScriptBin "fhs-runner" ''
    exec -a "$@"
  '';
  etcPkg = stdenv.mkDerivation {
    name         = "capt-chrootenv-etc";
    buildCommand = ''
      mkdir -p $out/etc
      cd $out/etc

      ln -s /host/etc/cups cups
      ln -s /host/etc/ccpd.conf ccpd.conf
    '';
    meta.priority = -100;
  };
  fhsEnv = buildFHSUserEnv {
    name = "canon-capt-driver-env";
    targetPkgs = pkgs: [ common capt fhs-runner etcPkg ];
    runScript = "${fhs-runner}/bin/fhs-runner";
  };
  fhsEnvExecutable = "${fhsEnv}/bin/${fhsEnv.name}";

in runCommand "canon-capt-driverpack" {
    pname = "canon-capt-driverpack";
    version = "2.71";

    src = null;

    buildInputs = [ makeWrapper ];

    meta = with stdenv.lib; {
      description = "Canon CAPT driver pack";
      homepage = https://global.canon;
      maintainers = [ maintainers.wizzup ];
      platforms = platforms.linux;

      #NOTE: desc taken from : https://th.canon/th/support/0100459601/7
      longDescription = ''
        This CAPT printer driver provides printing functions for Canon LBP printers operating under the CUPS (Common Unix Printing System) environment, a printing system that functions on Linux operating systems.
      '';

      #FIXME: not sure about license
      #       https://th.canon/en/support/0100459601/7
      # license = licenses.gpl3Plus;
    };

  } ''
    mkdir -p $out/bin
    function _redirect() {
      local name=$1 path=$2
      mkdir -p "$out/$path"
      cat >"$out/$path/$name" <<EOF ${''
        ${/* line intentionally left blank */ ""}
        #! ${stdenv.shell} -e
        echo calling /$path/$name "\$@" wrapper 1>&2
        ${coreutils}/bin/env 1>&2
        exec ${fhsEnvExecutable} "$name" "/$path/$name" "\$@"
        EOF
      ''}
      chmod +x $out/$path/$name
    }
    for dir in bin lib/cups/backend lib/cups/filter; do
      for drv in ${common} ${capt}; do
        local binPath=$drv/$dir
        [ -d $binPath ] || continue
        for bin in $binPath/*; do
          _redirect $(basename $bin) $dir
        done
      done
    done

    # Work around a corner-case limitation of buildFHSUserEnv:
    # /etc is populated with symlinks to /host/etc, but is not the real /etc
    # itself, nor a symlink thereto. ccpdadmin write /etc/ccpd.conf~ and then
    # moves that file to /etc/ccpd.conf. This cannot be fixed with clever
    # symlinks, so just move ccpdadmin outside of the fhsEnv.
    makeWrapper ${capt}/bin/ccpdadmin $out/bin/ccpdadmin \
      --prefix PATH : "$out"

    mkdir -p $out/share
    ln -sn ${capt}/share/cups $out/share/cups
  ''

#    mkdir -p $out/lib/systemd/system
#    cat > $out/lib/systemd/system/ccpd.service <<EOF ${''
#      ${/* line intentionally left blank */ ""}
#      # original : https://aur.archlinux.org/cgit/aur.git/plain/ccpd.service?h=capt-src
#
#      [Unit]
#      Description=Canon CAPT daemon
#      Requires=cups.service
#      After=cups.service
#
#      [Service]
#      Type=forking
#      ExecStart=$out/bin/ccpd
#
#      [Install]
#      WantedBy=printer.target
#      EOF
#    ''}
#  */
#  ''
