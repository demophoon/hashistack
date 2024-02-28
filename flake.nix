{
  description = "Hashistack, but with nix!";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=e49c28b3baa3a93bdadb8966dd128f9985ea0a09";
  };

  outputs = { self, nixpkgs }:
  let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
  in
  {
    devShells.${system}.default =
      pkgs.mkShell {
        buildInputs = with pkgs; [
          nomad
          consul
          vault
        ];
      };
  };

}
