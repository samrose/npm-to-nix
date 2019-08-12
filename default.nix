{ lib, fetchurl, buildEnv, runCommand }:

with lib;

let
  unpackTo = prefix: path: runCommand "source" {} ''
    mkdir $out
    tar -xaf ${path} -C $out

    if [ ! -e $out/package ]; then
      mkdir $out/package
      mv -f $out/* $out/package || true
    fi

    mkdir -p $out/$(dirname ${prefix})
    mv $out/package $out/${prefix}
  '';

  fetchPackage = prefix: { resolved, integrity, ... }:
    unpackTo prefix (fetchurl {
      url = resolved;
      hash = integrity;
    });
in

{
  npmToNix = { src }:
    let
      lockFile = importJSON "${src}/package-lock.json";
    in
    buildEnv {
      name = "node_modules";
      paths = mapAttrsToList fetchPackage lockFile.dependencies;
    };
}
