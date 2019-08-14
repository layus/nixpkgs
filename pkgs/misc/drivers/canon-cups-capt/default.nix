{ stdenv
, runCommand
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
    prog=$1
    shift
    exec /bin/$prog "$@"
  '';
  fhsEnv = buildFHSUserEnv {
    name = "canon-capt-driver-env";
    targetPkgs = pkgs: [ common capt fhs-runner ];
    runScript = "/bin/fhs-runner";
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
      local target=$1 name=$(basename "$1")
      cat >$out/bin/$name <<EOF
    #! ${stdenv.shell} -e
    exec ${fhsEnvExecutable} "$name" "$@"
    EOF
      chmod +x $out/bin/$name
    }
    for target in ${common}/bin/* ${capt}/bin/* ; do
      _redirect "$target"
    done

    mkdir -p $out/share
    ln -sn ${capt}/share/cups $out/share/cups

    mkdir -p $out/lib/system/systemd
    cat > $out/lib/system/systemd/ccpd.service <<EOF
    # original : https://aur.archlinux.org/cgit/aur.git/plain/ccpd.service?h=capt-src

    [Unit]
    Description=Canon CAPT daemon
    Requires=org.cups.cupsd.service
    After=org.cups.cupsd.service

    [Service]
    Type=forking
    ExecStart=/usr/bin/ccpd

    [Install]
    WantedBy=printer.target
    EOF
  ''
