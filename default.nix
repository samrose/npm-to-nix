{ lib, fetchurl, buildEnv, runCommand }:

with lib;

let
  prefixPath = prefix: path: runCommand "source" {} ''
    mkdir -p $(dirname $out/${prefix})
    ln -s ${path} $out/${prefix}
  '';

  unpack = path: runCommand "source" {} ''
    mkdir $out
    tar -xaf ${path} -C $out --strip-components=1
  '';

  fetchGitPackage = { from, version, ... }:
    let
      urlAndRef = splitString "#" from;
      urlAndRev = splitString "#" version;
      url = replaceStrings [ "git://" ] [ "https://" ] (head urlAndRef);
      ref = last urlAndRef;
      rev = last urlAndRev;
    in
    fetchGit {
      inherit url ref rev;
    };

  fetchURLPackage = { resolved, integrity, ... }: unpack (fetchurl {
    url = resolved;
    hash = integrity;
  });

  fetchPackage = prefix: attrs:
    let
      fetch = if attrs ? "from"
        then fetchGitPackage
        else fetchURLPackage;
    in
    prefixPath prefix (fetch attrs);
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
