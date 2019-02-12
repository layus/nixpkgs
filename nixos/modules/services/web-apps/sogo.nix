{ config, lib, pkgs, ... }@args:

with lib;

let
  cfg = config.services.sogo;
  sogo = pkgs.sogo.SOGo;

in {
  options.services.sogo = {
    enable = mkEnableOption "sogo";
    hostName = mkOption {
      type = types.str;
      description = "FQDN for the sogo instance.";
    };
    home = mkOption {
      type = types.str;
      default = "/var/lib/sogo";
      description = "Storage path of sogo.";
    };

    nginx.enable = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Whether to enable nginx virtual host management.
        Further nginx configuration can be done by adapting <literal>services.nginx.virtualHosts.&lt;name&gt;</literal>.
        See <xref linkend="opt-services.nginx.virtualHosts"/> for further information.
      '';
    };

    config = mkOption {
      type = types.string;
      description = "SOGo configuration. See https://sogo.nu/files/docs/SOGoInstallationGuide.html";
      example = ''
        {
            SOGoProfileURL = "postgresql://sogo:sogo@localhost:5432/sogo/sogo_user_profile";
            OCSFolderInfoURL = "postgresql://sogo:sogo@localhost:5432/sogo/sogo_folder_info";
            OCSSessionsFolderURL = "postgresql://sogo:sogo@localhost:5432/sogo/sogo_sessions_folder";

            SOGoAppointmentSendEMailNotifications = YES;
            SOGoCalendarDefaultRoles = (
                PublicViewer,
                ConfidentialDAndTViewer
            );
            SOGoLanguage = English;
            SOGoTimeZone = Europe/Brussels;
            SOGoMailDomain = acme.com;
            SOGoIMAPServer = 127.0.0.1;
            SOGoDraftsFolderName = Drafts;
            SOGoSentFolderName = Sent;
            SOGoTrashFolderName = Trash;
            SOGoJunkFolderName = Junk;
            SOGoMailingMechanism = smtp;
            SOGoSMTPServer = 127.0.0.1;
            SOGoUserSources = (
                {
                    type = ldap;
                    CNFieldName = cn;
                    IDFieldName = uid;
                    UIDFieldName = uid;
                    baseDN = "ou=users,dc=acme,dc=com";
                    bindDN = "uid=sogo,ou=users,dc=acme,dc=com";
                    bindPassword = qwerty;
                    canAuthenticate = YES;
                    displayName = "Shared Addresses";
                    hostname = 127.0.0.1;
                    id = public;
                    isAddressBook = YES;
                    port = 389;
                }
            );
        }
      '';
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      systemd.services = {
        "sogo" = {
          after = [ "local-fs.target" ];
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            User = "sogo";
            ExecStart = ''${sogo}/bin/sogod -WOWorkersCount 1 -WOPidFile /var/lib/sogo/sogo.pid -WOLogFile /var/log/sogo/sogo.log'';
            PIDFile = "/var/lib/sogo/sogo.pid";
            Type = "forking";
            PermissionsStartOnly = true;
          };
          preStart = ''
            ${pkgs.coreutils}/bin/mkdir -p /var/log/sogo
            chown sogo /var/log/sogo

            if ! test -e "/var/lib/sogo/db-created"; then
              sleep 2
              ${pkgs.sudo}/bin/sudo -u ${config.services.postgresql.superUser} \
                ${config.services.postgresql.package}/bin/psql postgres -c \
                  "CREATE ROLE ${"sogo"} WITH LOGIN NOCREATEDB NOCREATEROLE ENCRYPTED PASSWORD '${"sogo"}'"
              ${pkgs.sudo}/bin/sudo -u ${config.services.postgresql.superUser} \
                ${config.services.postgresql.package}/bin/createdb -O ${"sogo"} ${"sogo"}
              ${pkgs.coreutils}/bin/touch /var/lib/sogo/db-created
            fi
          '';
        };
      };

      users.extraUsers.sogo = {
        home = "${cfg.home}";
        createHome = true;
      };

      environment.etc."sogo/sogo.conf".text = cfg.config;

      environment.systemPackages = [ sogo ];
    }

    (mkIf cfg.nginx.enable {
      networking.firewall.allowedTCPPorts = [ 80 ];
      systemd.services.sogo.wantedBy = [ "nginx.service" ];
      services.nginx = {
        enable = true;
        virtualHosts = {
          "${cfg.hostName}" = {
            root = "${sogo}/lib/GNUstep/SOGo/WebServerResources";
            locations = {
              "/".extraConfig = ''
                rewrite ^ ${cfg.hostName}/SOGo;
                allow all;
              '';
              "= /principals/".extraConfig = ''
                rewrite ^ https://$server_name/SOGo/dav;
                allow all;
              '';
              "^~/SOGo".extraConfig = ''
                proxy_pass http://127.0.0.1:20000;
                proxy_redirect http://127.0.0.1:20000 default;
                # forward user's IP address
                proxy_set_header X-Real-IP $remote_addr;
                proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                proxy_set_header Host $host;
                proxy_set_header x-webobjects-server-protocol HTTP/1.0;
                proxy_set_header x-webobjects-remote-host 127.0.0.1;
                proxy_set_header x-webobjects-server-name $server_name;
                proxy_set_header x-webobjects-server-url $scheme://$host;
                proxy_connect_timeout 90;
                proxy_send_timeout 90;
                proxy_read_timeout 90;
                proxy_buffer_size 4k;
                proxy_buffers 4 32k;
                proxy_busy_buffers_size 64k;
                proxy_temp_file_write_size 64k;
                client_max_body_size 50m;
                client_body_buffer_size 128k;
                break;
              '';
              "/SOGo.woa/WebServerResources/".extraConfig = ''
                alias ${sogo}/lib/GNUstep/SOGo/WebServerResources/;
                allow all;
              '';
              "/SOGo/WebServerResources/".extraConfig = ''
                alias ${sogo}/lib/GNUstep/SOGo/WebServerResources/;
                allow all;
              '';
              "~ ^/SOGo/so/ControlPanel/Products/([^/]*)/Resources/(.*)$".extraConfig = ''
                alias ${sogo}/usr/lib/GNUstep/SOGo/$1.SOGo/Resources/$2;
              '';
              "~ ^/SOGo/so/ControlPanel/Products/[^/]*UI/Resources/.*\.(jpg|png|gif|css|js)$".extraConfig = ''
                alias ${sogo}/usr/lib/GNUstep/SOGo/$1.SOGo/Resources/$2;
              '';
            };
            extraConfig = ''
              autoindex off;
            '';
          };
        };
      };
    })
  ]);

  #meta.doc = ./sogo.xml;
}
