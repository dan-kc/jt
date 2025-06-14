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
            ];
            env = {
              TEMPLATES_DIR = "./templates";
            };
          };
        packages.default = package;
      }
    );
}
