# nix/nixosModules.nix — NixOS module for hermes-webui
#
# Provides a systemd service running the standalone Hermes Web UI.
# The webui discovers the hermes-agent via HERMES_HOME or HERMES_WEBUI_AGENT_DIR.
#
# Usage:
#   services.hermes-webui = {
#     enable = true;
#     host = "0.0.0.0";
#     port = 8787;
#   };
#
{ inputs, ... }: {
  flake.nixosModules.default = { config, lib, pkgs, ... }:

  let
    cfg = config.services.hermes-webui;
    hermes-webui = inputs.self.packages.${pkgs.system}.default;
  in {
    options.services.hermes-webui = with lib; {
      enable = mkEnableOption "Hermes Web UI service";

      package = mkOption {
        type = types.package;
        default = hermes-webui;
        description = "The hermes-webui package to use.";
      };

      host = mkOption {
        type = types.str;
        default = "127.0.0.1";
        description = "Host address to bind the web UI to.";
      };

      port = mkOption {
        type = types.int;
        default = 8787;
        description = "Port for the web UI to listen on.";
      };

      stateDir = mkOption {
        type = types.str;
        default = "/var/lib/hermes-webui";
        description = "State directory for sessions and settings.";
      };

      user = mkOption {
        type = types.str;
        default = "hermes-webui";
        description = "System user running the web UI.";
      };

      group = mkOption {
        type = types.str;
        default = "hermes-webui";
        description = "System group running the web UI.";
      };

      hermesHome = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = ''
          Path to HERMES_HOME. If set, the webui will discover the
          hermes-agent installation and config from this directory.
        '';
      };

      environmentFiles = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Paths to environment files (e.g. for HERMES_WEBUI_PASSWORD).";
      };

      extraPackages = mkOption {
        type = types.listOf types.package;
        default = [ ];
        description = "Extra packages available on PATH.";
      };
    };

    config = lib.mkIf cfg.enable {
      users.groups.${cfg.group} = { };
      users.users.${cfg.user} = {
        isSystemUser = true;
        group = cfg.group;
        home = cfg.stateDir;
        createHome = true;
      };

      systemd.tmpfiles.rules = [
        "d ${cfg.stateDir}            2770 ${cfg.user} ${cfg.group} - -"
        "d ${cfg.stateDir}/sessions   2770 ${cfg.user} ${cfg.group} - -"
      ];

      systemd.services.hermes-webui = {
        description = "Hermes Web UI";
        wantedBy = [ "multi-user.target" ];
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];

        environment = {
          HERMES_WEBUI_HOST = cfg.host;
          HERMES_WEBUI_PORT = toString cfg.port;
          HERMES_WEBUI_STATE_DIR = "${cfg.stateDir}";
        } // lib.optionalAttrs (cfg.hermesHome != null) {
          HERMES_HOME = cfg.hermesHome;
        };

        serviceConfig = {
          User = cfg.user;
          Group = cfg.group;
          WorkingDirectory = "${cfg.package}/share/hermes-webui";

          ExecStart = "${cfg.package}/bin/hermes-webui";

          Restart = "always";
          RestartSec = 5;
          UMask = "0007";

          # Hardening
          NoNewPrivileges = true;
          ProtectSystem = "strict";
          ProtectHome = false;
          ReadWritePaths = [ cfg.stateDir ];
          PrivateTmp = true;
        };

        path = [
          cfg.package
          pkgs.bash
          pkgs.coreutils
        ] ++ cfg.extraPackages;
      };
    };
  };
}
