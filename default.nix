{ lib, fetchurl, runCommand, symlinkJoin }:

with lib;

let
  resolveBin = name: target: source: ''
    ln -rs $out/${name}/${source} $out/.bin/${target}
  '';

  resolvePackage = { name, src, nodeModules }:
  let
    meta = importJSON "${src}/package.json";
    bin = {
      null = {};
      string."${meta.name}" = meta.bin;
      set = meta.bin;
    }."${builtins.typeOf meta.bin or null}";
  in
  runCommand "source" {} ''
    mkdir -p $out/.bin
    mkdir -p $(dirname $out/${name})
    cp -Lr ${src} $out/${name}
    ${concatStringsSep "\n" (mapAttrsToList (resolveBin name) bin)}
    chmod -R +x $out/.bin
    chmod -R +w $out
    cp -r ${nodeModules} $out/${name}/node_modules
  '';

  unpack = path: runCommand "source" {} ''
    mkdir $out
    tar -xaf ${path} -C $out --strip-components=1
  '';

  fetchGitPackage = { from, version, ... }:
    let
      urlAndRef = splitString "#" from;
      urlAndRev = splitString "#" version;
      url = replaceStrings [ "git://" "github:" ] [ "https://" "https://github.com/" ] [ "git+https" "https" ] (head urlAndRef);
      ref = if length urlAndRef == 1
        then "HEAD"
        else last urlAndRef;
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


  buildNodeModulesSymlinked = deps: symlinkJoin {
    name = "node_modules";
    paths = mapAttrsToList buildPackage deps;
  };

  buildNodeModules = deps:
    let
      nodeModules = buildNodeModulesSymlinked deps;
    in
    runCommand "node_modules" {} ''
      mkdir -p $out
      for f in ${nodeModules}/*; do
        cp -Lr $f $out
      done
      cp -r ${nodeModules}/.bin $out || true
    '';
in

{
  npmToNix = { src }:
    let
      lockFile = importJSON "${src}/package-lock.json";
    in
    buildNodeModules lockFile.dependencies;
}
