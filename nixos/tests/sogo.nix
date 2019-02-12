import ./make-test.nix {
  name = "sogo";

  machine = { pkgs, ... }: {
    imports = [ common/user-account.nix ];
    virtualisation.memorySize = 2047;

    services.sogo = {
      enable = true;
      hostName = "http://127.0.0.1:8000";
      config = ''
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
                    baseDN = "ou=users,dc=example,dc=org";
                    bindDN = "uid=sogo,ou=users,dc=example,dc=org";
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

    systemd.services.sogo.requires = [ "postgresql.service" "openldap.service" ];
    systemd.services.sogo.after = [ "postgresql.service" "openldap.service" ];

    services.postgresql.enable = true;
    services.openldap = {
      enable = true;
      declarativeContents = ''
        dn: dc=example,dc=org
        objectClass: domain
        dc: example

        dn: ou=users,dc=example,dc=org
        objectClass: organizationalUnit
        ou: users

        dn: uid=sogo,ou=users,dc=example,dc=org
        objectClass: top
        objectClass: inetOrgPerson
        objectClass: person
        objectClass: organizationalPerson
        uid: sogo
        cn: SOGo Administrator
        mail: sogo@example.org
        sn: Administrator
        givenName: SOGo
        userPassword: qwerty
      '';
      extraConfig = ''
        include ${pkgs.openldap.out}/etc/schema/core.schema
        include ${pkgs.openldap.out}/etc/schema/cosine.schema
        include ${pkgs.openldap.out}/etc/schema/inetorgperson.schema
        include ${pkgs.openldap.out}/etc/schema/nis.schema

        database bdb
        suffix dc=example,dc=org
        rootdn cn=admin,dc=example,dc=org
        rootpw secret
        directory /var/db/openldap
      '';
    };
  };

  testScript = ''
    $machine->waitForUnit('sogo.service');
    $machine->waitForUnit('nginx.service');
    print $machine->execute('curl -vL http://127.0.0.1/SOGo/login');
  '';
}
