{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  buildInputs = [
    pkgs.flutter
    pkgs.jdk17
    pkgs.unzip
  ];
}
