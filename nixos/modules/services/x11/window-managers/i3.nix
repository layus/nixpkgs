{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.xserver.windowManager.i3;
in

{
  options = {
    services.xserver.windowManager.i3 = {
      enable = mkOption {
        default = false;
        example = true;
        description = "Enable the i3 tiling window manager.";
      };

      configFile = mkOption {
        default = null;
        type = types.nullOr types.path;
        description = ''
          Path to the i3 configuration file.
          If left at the default value, $HOME/.i3/config will be used.
        '';
      };

      verbose = mkOption {
        default = false;
        example = true;
        type = types.bool;
        description = "Enable verbose logging (see -V option)";
      };

      debug = mkOption {
        default = false;
        example = true;
        type = types.bool;
        description = ''
          Enable debug logging (see '-d all' option)
          This option implies verbose logging.
        '';
      };

      logFile = mkOption {
        default = null;
        example = "$HOME/.i3/i3log";
        type = types.nullOr types.string;
        description = ''
          Path to a logfile for i3.
          If left at the default value, logs will appear in display-manager.service's logs.
        '';
      };
    };
  };

  config = mkIf cfg.enable {
    services.xserver.windowManager = {
      session = [{
        name = "i3";
        start = ''
          ${pkgs.i3}/bin/i3 ${optionalString (cfg.configFile != null)
            ''-c "${cfg.configFile}"''
          } ${optionalString (cfg.verbose || cfg.debug)
            ''-V''
          } ${optionalString cfg.debug
            ''-d all''
          } ${optionalString (cfg.logFile != null)
            ''>> "${cfg.logFile}"''
          } &
          waitPID=$!
        '';
      }];
    };
    environment.systemPackages = [ pkgs.i3 ];
  };
}
