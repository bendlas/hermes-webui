# nix/packages.nix — Hermes Web UI package
{ inputs, ... }: {
  perSystem = { pkgs, system, ... }:
    let
      python3 = pkgs.python311;

      # Python environment with only pyyaml (the sole declared dependency)
      webuiPythonEnv = python3.withPackages (ps: [ ps.pyyaml ]);

      # Clean source filter — exclude .git, caches, venvs, test artifacts
      webuiSrc = pkgs.lib.cleanSourceWith {
        src = inputs.self;
        filter = path: type:
          !(pkgs.lib.hasInfix "/.git/" path) &&
          !(pkgs.hasSuffix ".pyc" path) &&
          !(pkgs.lib.hasInfix "/__pycache__/" path) &&
          !(pkgs.lib.hasInfix "/.venv/" path) &&
          !(pkgs.lib.hasInfix "/node_modules/" path);
      };

    in {
      packages.default = pkgs.stdenv.mkDerivation {
        pname = "hermes-webui";
        version = "0.50.76";

        src = webuiSrc;

        dontBuild = true;
        nativeBuildInputs = [ pkgs.makeWrapper ];

        installPhase = ''
          runHook preInstall

          mkdir -p $out/share/hermes-webui $out/bin

          # Copy the entire source tree (server.py, api/, static/, etc.)
          cp -r . $out/share/hermes-webui/

          # Create wrapper script that runs server.py with the right Python
          makeWrapper ${webuiPythonEnv}/bin/python $out/bin/hermes-webui \
            --add-flags $out/share/hermes-webui/server.py \
            --set HERMES_WEBUI_AGENT_DIR "" \
            --prefix PYTHONPATH : "$out/share/hermes-webui"

          runHook postInstall
        '';

        meta = with pkgs.lib; {
          description = "Claude-style web UI for Hermes Agent";
          homepage = "https://github.com/nesquena/hermes-webui";
          mainProgram = "hermes-webui";
          license = licenses.mit;
          platforms = platforms.unix;
        };
      };
    };
}
