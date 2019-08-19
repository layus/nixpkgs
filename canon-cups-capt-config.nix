let nixpkgs = import ./. { };

in {
  systemd.packages = [ nixpkgs.canon-cups-capt ];
  services.printing.drivers = [ nixpkgs.canon-cups-capt ];
}

