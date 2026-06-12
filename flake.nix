{
  description = "pg_spawner — development environment";
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
  outputs = { nixpkgs, ... }:
    let
      systems = [ "aarch64-darwin" "x86_64-darwin" "x86_64-linux" "aarch64-linux" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in {
      devShells = forAllSystems (pkgs: let
        mkShell = elixir: pkgs.mkShell {
          buildInputs = [
            elixir
            pkgs.postgresql_18
          ];

          shellHook = ''
            mkdir -p .nix/mix .nix/hex
            export HEX_HOME=$PWD/.nix/hex MIX_HOME=$PWD/.nix/mix
            export PATH=$MIX_HOME/bin:$HEX_HOME/bin:$PATH
            export ERL_AFLAGS="-kernel shell_history enabled"
          '';
        };
      in {
        default = mkShell pkgs.beam29Packages.elixir_1_20;
        # Used by CI to test against the previous Elixir release.
        # Elixir 1.19 supports OTP 26-28, so it gets the OTP 28 package set.
        elixir119 = mkShell pkgs.beam28Packages.elixir_1_19;
      });
    };
}
