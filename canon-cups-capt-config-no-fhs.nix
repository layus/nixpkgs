let
  nixpkgs = import ./. { };
  inherit (nixpkgs.pkgs) cndrvcups-capt cndrvcups-common;
in {
  systemd.services.ccpd = {
    description = "Canon CUPS Printing Daemon";
    serviceConfig = {
      Type = "forking";
      ExecStart = "${cndrvcups-capt}/bin/ccpd";
      Restart = "on-failure";
    };
    preStart = ''
      mkdir -p /var/captmon
    '';
    wantedBy = [ "printer.target" ];
    after = [ "cups.service" ];
    requires = [ "cups.service" ];
  };
  services.printing.drivers = [ cndrvcups-capt cndrvcups-common ];
  services.printing.enable = true;

  environment.systemPackages = [ cndrvcups-capt cndrvcups-common ];
}

