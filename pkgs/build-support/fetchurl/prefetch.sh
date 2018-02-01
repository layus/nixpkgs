#!/usr/bin/env nix-shell
#!nix-shell -i bash -p jshon diffutils

set -e
set -o pipefail

main () {
    local drvAttr=$1
    local newVersion='"'$2'"'

    # Get the old hash _before_ bumping the version.
    local oldHash=$(nixVal "$drvAttr.src.outputHash")

    if [ "$newVersion" != '""' ]; then
        log "Bumping version..."
        local oldVersion=$(nixVal "$drvAttr._args.version")
        local versionFile=$(nixAttrFile "$drvAttr._args" '"version"')
        update "$versionFile" "$oldVersion" "$newVersion"
    fi

    log "Prefetching source..."
    local newHash='"'$(nix-prefetch-url -A "$drvAttr.src")'"'

    log "Rewriting hash..."
    local hashMethod=$(nixVal "$drvAttr.src.outputHashAlgo")
    local hashFile=$(nixAttrFile "$drvAttr.src._args" "$hashMethod")
    update "$hashFile" "$oldHash" "$newHash"
}

update () {
    local file=$1 old=$2 new=$3
    [ -f "$file" ] || exit 1
    diff -U3 "$file" <(sed -e "s/$old/$new/" "$file") --color || true
    sed -e "s/$old/$new/" -i "$file"
}

nixVal () {
    local expr=$1; shift

    nix-instantiate --eval --strict -E "
      #begin:nix
      with (import ./. {
        overlays = [ (self: super: with super; {
          fetchurl = _args: (fetchurl _args) // { inherit _args; };
          stdenv = stdenv // {
            mkDerivation = _args: (stdenv.mkDerivation _args) // { inherit _args; };
          };
        })];
      }).pkgs;
      #end:nix
    $expr" $@
}

nixAttrFile () {
    nixVal "builtins.unsafeGetAttrPos $2 $1" --json | jshon -e file -u
}

log () { echo >&2; echo "$@" >&2; }

# Run the stuff!
main "$@"
