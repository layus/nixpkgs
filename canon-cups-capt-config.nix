let
  nixpkgs = import ./. { };
  inherit (nixpkgs) canon-cups-capt;

in {
  systemd.services.ccpd = {
    description = "Canon CUPS Printing Daemon";
    serviceConfig = {
      Type = "forking";
      ExecStart = "${canon-cups-capt}/bin/ccpd";
      Restart = "on-failure";
    };
    preStart = ''
      mkdir -p /var/captmon
    '';
    wantedBy = [ "printer.target" ];
    after = [ "cups.service" ];
    requires = [ "cups.service" ];
  };
  services.printing.drivers = [ canon-cups-capt ];
  services.printing.enable = true;

  environment.systemPackages = [ canon-cups-capt ];
}

