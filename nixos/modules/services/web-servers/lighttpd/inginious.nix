{ config, lib, pkgs, ... }:
with lib;

let
  cfg = config.services.lighttpd.inginious;
  inginious = pkgs.pythonPackages.inginious;
  execName = "inginious-${if cfg.useLTI then "lti" else "webapp"}";

  inginiousConfigFile = if cfg.configFile != null then cfg.configFile else pkgs.writeText "inginious.yaml" ''
    # Backend; can be:
    # - "local" (run containers on the same machine)
    # - "remote" (connect to distant docker daemon and auto start agents) (choose this if you use boot2docker)
    # - "remote_manual" (connect to distant and manually installed agents)
    backend: "${if cfg.local "local" else "remote_manual"}"

    # List of remote docker daemon to which the backend will try
    # to connect (backend: remote only) (the default config below is the one for boot2docker on OS X)
    docker_daemons:
      - # Host of the docker daemon *from the webapp*
        remote_host: "${"localhost"}" 
        # Port of the distant docker daemon *from the webapp*
        remote_docker_port: "${"2375"}"
        # A mandatory port used by the backend and the agent that will be automatically started.
        # Needs to be available on the remote host, and to be open in the firewall.
        remote_agent_port: "${"63456"}"
        # Does the remote docker requires tls? Defaults to false.
        # Parameter can be set to true or path to the certificates
        #use_tls: false
        # Link to the docker daemon *from the host that runs the docker daemon*. Defaults to:
        #local_location: "unix:///var/run/docker.sock"
        # Path to the cgroups "mount" *from the host that runs the docker daemon*. Defaults to:
        #cgroups_location: "/sys/fs/cgroup"
        # Name that will be used to reference the agent
        #"agent_name": "inginious-agent"

    # List of remote agents to which the backend will try
    # to connect (backend: remote_manual only) (the default config below is the one for boot2docker on OS X)
    #agents:
    #  - host: "192.168.59.103"
    #    port: 5001
    ${assert cfg.local or cfg.remoteAgents != null;
    lib.optionalString !cfg.local ''
      agents:
      ${lib.concatMapStrings (agent: ''
        ${}  - host: "${agent.host}"
        ${}    port: ${agent.port}
      '') cfg.remoteAgents}
    ''}

    # Location of the task directory
    tasks_directory: "${cfg.tasksDirectory}"

    # Super admins: list of user names that can do everything in the backend
    superadmins:
    ${lib.concatMapStrings (x: "  - \"${x}\"\n") cfg.superadmins}

    # Use single minified javascript file (production) or multiple files (dev) ?
    use_minified_js: true

    ## TODO: Add NixOS options for these required parameters.

    # MongoDB options
    mongo_opt:
        host: localhost
        database: INGInious

    # Aliases for containers
    # Only containers listed here can be used by tasks
    containers:
        default: ingi/inginious-c-default
        sekexe:  ingi/inginious-c-sekexe
        java:    ingi/inginious-c-java
        oz:      ingi/inginious-c-oz

    # Plugins that will be loaded by the webapp
    plugins:
      - plugin_module: inginious.frontend.webapp.plugins.auth.demo_auth
        users:
            # register the user "test" with the password "test"
            test: test

    # Disable INGInious?
    #maintenance: false

    #smtp:
    #    sendername: 'INGInious <no-reply@inginious.org>'
    #    host: 'smtp.gmail.com'
    #    port: 587
    #    username: 'configme@gmail.com'
    #    password: 'secret'
    #    starttls: True

    ${cfg.extraConfig}
  '';
in
{
  options.services.lighttpd.inginious = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Whether to enable INGInious, an automated code testing and grading system.
      '';
    };

    configFile = mkOption {
      #type = types.path;
      default = null;
      example = literalExample ''pkgs.writeText "httpd.conf" "# custom config options ...";'';
      description = '' A path to an INGInious configuration file. '';
    };

    extraConfig = mkOption {
      type = types.lines;
      default = "";
      description = '' Extra option in YaML format, to be appended to the config file. '';
    };

    tasksDirectory = mkOption {
      type = types.path;
      default = "/var/lib/INGInious/tasks";
      description = '' Path to inginious tasks '';
    };

    useLTI = mkOption {
      type = types.bool;
      default = false;
      description = '' Whether to use the LTI frontend in place of the webapp. '';
    };

    superadmins = mkOption {
      type = types.uniq (types.listOf types.str);
      default = [ "admin" ];
      example = ''[ "john" "pepe" "emilia" ]'';
      description = ''List of user logins allowed to administrate the whole server.'';
    };

    hostPattern = mkOption {
      type = types.str;
      default = "^inginious.";
      example = "^inginious.mydomain.xyz$";
      description = ''
        The domain that serves INGInious.
        INGInious uses absolute paths which makes it difficult to relocate in its own subdir.
        The default configuration will serve INGInious when the server is accessed with a hostname starting with "inginious.".
        If left blank, INGInious will take the precedence on all the other lighttpd submodules, which is probably not what you want.
      '';
    };

    local = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Set to false if you want to use remote graging agents.
        Remember to provide a list of agents in that case.
      '';
    };

    remoteAgents = mkOption {
      type = types.nullOr (types.listOf (types.attrsOf types.str));
      default = null;
      example = [  { host = "145.33.17.89"; port = "1345"; } ];
      description = '' A list of remote agents . '';
    };
  };

  config = mkIf cfg.enable (
    mkMerge [
      # For a local install, we need docker.
      (mkIf cfg.local {
        virtualisation.docker = {
          enable = true;
          extraOptions = "-H tcp://localhost:2375 -H unix:///var/run/docker.sock";
          storageDriver = "overlay";
        };

        users.extraUsers."lighttpd".extraGroups = [ "docker" ];
      })
      # Common 
      {
        services.mongodb.enable = true;

        services.lighttpd.enable = true;
        services.lighttpd.enableModules = [ "mod_access" "mod_alias" "mod_fastcgi" "mod_redirect" "mod_rewrite" ];
        services.lighttpd.extraConfig = ''
          $HTTP["host"] =~ "${hostPattern}" {
            fastcgi.server = ( "/inginious" =>
              (( 
                "socket" => "/tmp/fastcgi.socket",
                "bin-path" => "${inginious}/bin/${execName} --config=${inginiousConfigFile}",
                "max-procs" => 1,
                "bin-environment" => (
                  ${lib.optionalString false ''"DOCKER_HOST" => "tcp://192.168.59.103:2375",'' }
                  "REAL_SCRIPT_NAME" => ""
                  ),
                "check-local" => "disable"
              ))
            )
            url.rewrite-once = (
              "^/static/" => "$0",
              "^/.*$" => "/${execName}$0",
              "^/favicon.ico$" => "/static/common/favicon.ico",
            )
            alias.url += (
              "/static/webapp/" => "${inginious}/lib/python2.7/site-packages/inginious/frontend/webapp/static/",
              "/static/common/" => "${inginious}/lib/python2.7/site-packages/inginious/frontend/common/static/"
            )
          }
        '';
      }
    ];
}
