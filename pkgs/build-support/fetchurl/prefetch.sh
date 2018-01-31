#!/usr/bin/env nix-shell
#!nix-shell -i bash -p jshon diffutils

set -e
set -o pipefail

update () {
    local file=$1 old=$2 new=$3
    [ -f "$file" ] || exit 1
    diff -U3 "$file" <(sed -e "s/$old/$new/" "$file") --color || true
    sed -e "s/$old/$new/" -i "$file"
}

getAttr () {
    nix-instantiate --eval --strict -A "$@"
}

getAttrFile () {
    nix-instantiate --eval --strict -E "with (import ./. {}).pkgs; builtins.unsafeGetAttrPos $2 $1" --json | jshon -e file -u
}

log () {
    echo >&2
    echo "$@" >&2
}


attr=$1
newVersion='"'$2'"'

oldHash=$(getAttr "$1.src.outputHash")

if [ -n "$2" ]; then
    log "Bumping version..."
    oldVersion=$(getAttr "$1._attrs.version")
    versionFile=$(getAttrFile "$1._attrs" '"version"')
    update "$versionFile" "$oldVersion" "$newVersion"
fi

log "Prefetching source..."
newHash='"'$(nix-prefetch-url -A "$1.src")'"'

log "Rewriting hash..."
hashMethod=$(getAttr "$1.src.outputHashAlgo")
hashFile=$(getAttrFile "$1.src._args" "$hashMethod")
update "$hashFile" "$oldHash" "$newHash"

