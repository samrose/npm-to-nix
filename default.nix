{ lib, fetchurl, buildEnv, runCommand }:

with lib;

let
  resolvePackage = { name, src, nodeModules }: runCommand "source" {} ''
    mkdir -p $(dirname $out/${name})
    cp -rs ${src} $out/${name}
    chmod -R +w $out
    ln -s ${nodeModules} $out/${name}/node_modules
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

  buildPackage = name: attrs:
    let
      fetchPackage = if attrs ? "from"
        then fetchGitPackage
        else if attrs ? "resolved"
        then fetchURLPackage
        else null;

      dependencies = if attrs ? "dependencies"
        then attrs.dependencies
        else {};
    in
    if fetchPackage != null
    then resolvePackage {
      inherit name;
      src = fetchPackage attrs;
      nodeModules = buildNodeModules dependencies;
    }
    else null;

  buildNodeModules = dependencies: buildEnv {
    name = "node_modules";
    paths = mapAttrsToList buildPackage dependencies;
  };
in

{
  npmToNix = { src }:
    let
      lockFile = importJSON "${src}/package-lock.json";
    in
    buildNodeModules lockFile.dependencies;
}
