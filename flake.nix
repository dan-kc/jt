{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      nixpkgs,
      fenix,
      flake-utils,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        overlays = [ fenix.overlays.default ]; # Adds nightly rust analyser
        pkgs = import nixpkgs {
          inherit system overlays;
        };

        ra-multiplex-port = "27619";
        ra-config = ''
          instance_timeout = false 
          gc_interval = 10
          listen = ["127.0.0.1", ${ra-multiplex-port}]
          connect = ["127.0.0.1", ${ra-multiplex-port}]
          log_filters = "info"
          pass_environment = []
        '';
        ra = pkgs.writeShellScriptBin "ra" ''
          RA_MULTIPLEX_DIR="/tmp/ra-${ra-multiplex-port}"
          CONFIG_DIR="$RA_MULTIPLEX_DIR/ra-multiplex"  
          CONFIG_FILE="$CONFIG_DIR/config.toml"
          LOG_DIR="/tmp/ra-multiplex"
          LOG_FILE="$LOG_DIR/$RA_MULTIPLEX_PORT.log"

          mkdir -p "$LOG_DIR"
          mkdir -p "$CONFIG_DIR"
          cat > "$CONFIG_FILE" <<EOF
          ${ra-config}
          EOF

          XDG_CONFIG_HOME=$RA_MULTIPLEX_DIR ra-multiplex server &> "$LOG_FILE" & disown
          echo "Listening"
        '';

        toolchain = fenix.packages.${system}.minimal.toolchain;
        rustPlatform = pkgs.makeRustPlatform {
          cargo = toolchain;
          rustc = toolchain;
        };
        pname = "jt";
        package = rustPlatform.buildRustPackage {
          inherit pname;
          version = "0.1.0";
          src = ./.;
          cargoLock.lockFile = ./Cargo.lock;
          nativeBuildInputs = [ pkgs.makeWrapper ];
          buildInputs = [
            (pkgs.writeText "set-templates-dir" ''
              export TEMPLATES_DIR=${./templates}
            '')
          ];
          postInstall = ''
            mkdir -p $out/share/${pname}/templates
            cp ./templates/* $out/share/${pname}/templates
          '';
          postFixup = ''
            wrapProgram $out/bin/${pname} \
              --set TEMPLATES_DIR "$out/share/${pname}/templates"
          '';
        };
      in
      {
        devShells.default =
          with pkgs;
          mkShell {
            buildInputs = [
              (fenix.packages.${system}.complete.withComponents [
                "cargo"
                "clippy"
                "rustc"
                "rustfmt"
              ])
              rust-analyzer
              nil
              nixfmt-rfc-style
              taplo
              ra-multiplex
              ra
            ];
            env = {
              TEMPLATES_DIR = "./templates";
            };
            shellHook = ''
              export RA_MULTIPLEX_PORT="${ra-multiplex-port}"
            '';
          };
        packages.default = package;
      }
    );
}
