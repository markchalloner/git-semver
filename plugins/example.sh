#!/bin/bash

function run
{
    local version_new="$1"
    local version_current="$2"
    local git_hash="$3"
    local git_branch="$4"
    local git_root="$5"

    echo "New version: ${version_new}"
    echo "Current version: ${version_current}"
    echo "Current git hash: ${git_hash}"
    echo "Current git branch: ${git_branch}"
    echo "Git top level directory: ${git_root}"

    # No error
    return 0

    # Optional error: continue processing plugins and apply version tag
    #return 111
    #return 1

    # Compulsory error: continue processing plugins (to allow other generated errors) but stop before applying version tag
    #return 112

    # Forced error: stop immediately
    #return 113
}

case "${1}" in
    --about )
        echo -n "Check changelog has been updated along with code."
        ;;
    * )
        run "$@"
        ;;
esac
