{
  description = "dev env for secret_inject";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    utils.url = "github:numtide/flake-utils";
    rust-overlay.url = "github:oxalica/rust-overlay";
    crate2nix = {
      url = "github:kolloch/crate2nix";
      flake = false;
    };
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, utils, rust-overlay, crate2nix, ... }:
    let
      name = "nvim-github-codesearch";
    in
    utils.lib.eachDefaultSystem
      (system:
        let
          # Imports
          pkgs = import nixpkgs {
            inherit system;
            overlays = [
              rust-overlay.overlay
              (self: super: {
                # Because rust-overlay bundles multiple rust packages into one
                # derivation, specify that mega-bundle here, so that crate2nix
                # will use them automatically.
                rustc = self.rust-bin.stable.latest.default;
                cargo = self.rust-bin.stable.latest.default;
              })
            ];
          };
          inherit (import "${crate2nix}/tools.nix" { inherit pkgs; })
            generatedCargoNix;

          # Create the cargo2nix project
          project = pkgs.callPackage
            (generatedCargoNix {
              inherit name;
              src = ./.;
            })
            {
              # Individual crate overrides go here
              # Example: https://github.com/balsoft/simple-osd-daemons/blob/6f85144934c0c1382c7a4d3a2bbb80106776e270/flake.nix#L28-L50
              defaultCrateOverrides = pkgs.defaultCrateOverrides // {
                # The app crate itself is overriden here. Typically we
                # configure non-Rust dependencies (see below) here.
                ${name} = oldAttrs: {
                  inherit buildInputs nativeBuildInputs;
                } // buildEnvVars;
              };
            };

          # Configuration for the non-Rust dependencies
          buildInputs = with pkgs; [
            openssl.dev

            luajit
            pkg-config
            /* darwin.apple_sdk.frameworks.Security */
            libiconv
            /* openssl */
          ] ++ (if pkgs.system == "x86_64-darwin" || pkgs.system == "aarm64-darwin" then [
            darwin.apple_sdk.frameworks.Security
          ] else [ ]);
          nativeBuildInputs = with pkgs; [
            rustc
            cargo
            pkgconfig
            nixpkgs-fmt

            openssl.dev
            /* luajit */
            /* pkg-config */
            luajit
            pkg-config
            darwin.apple_sdk.frameworks.Security
            libiconv
            openssl
          ];
          buildEnvVars = {
            PKG_CONFIG_PATH = "${pkgs.openssl.dev}/lib/pkgconfig";
          };
        in
        rec {
          packages.${name} = project.rootCrate.build;

          # `nix build`
          defaultPackage = packages.${name};

          # `nix run`
          apps.${name} = utils.lib.mkApp {
            inherit name;
            drv = packages.${name};
          };
          defaultApp = apps.${name};

          # `nix develop`
          devShell = pkgs.mkShell
            {
              inherit buildInputs nativeBuildInputs;
              RUST_SRC_PATH = "${pkgs.rust.packages.stable.rustPlatform.rustLibSrc}";
            } // buildEnvVars;
        }
      );
}
