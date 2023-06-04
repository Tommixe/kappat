# https://status.nixos.org (nixpkgs-unstable)
{ pkgs ? import (fetchTarball "https://github.com/NixOS/nixpkgs/archive/e58a7747db96c23b8a977e7c1bbfc5753b81b6fa.tar.gz") {} }: 
let
  python-packages = pkgs.python3.withPackages (p: with p; [
    jinja2
    kubernetes
    netaddr
    rich
  ]);

  
  #https://lazamar.co.uk/nix-versions/?package=packer&version=1.8.0&fullName=packer-1.8.0&keyName=packer&revision=6e3a86f2f73a466656a401302d3ece26fba401d9&channel=nixpkgs-unstable#instructions
  pkgspacker = import (builtins.fetchTarball {
        url = "https://github.com/NixOS/nixpkgs/archive/6e3a86f2f73a466656a401302d3ece26fba401d9.tar.gz";
    }) {};
  
  myPacker = pkgspacker.packer;

in
pkgs.mkShell {
  buildInputs = with pkgs; [
    ansible
    ansible-lint
    bmake
    diffutils
    docker
    docker-compose_1 # TODO upgrade to version 2
    git
    go
    gotestsum
    iproute2
    jq
    k9s
    kube3d
    kubectl
    kubectx
    kubernetes-helm
    kustomize
    kubeseal
    libisoburn
    nano
    neovim
    openssh
    p7zip
    pre-commit
    shellcheck
    terraform
    yamllint

    python-packages

    myPacker
  ];
}


