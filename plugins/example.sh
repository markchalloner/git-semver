#!/bin/bash

function run() {
    # Parameters
    local version_new="$1"
    local version_current="$2"
    local git_hash="$3"
    local git_branch="$4"
    local git_root="$5"

    # Do something
    echo "New version: ${version_new}"
    echo "Current version: ${version_current}"
    echo "Current git hash: ${git_hash}"
    echo "Current git branch: ${git_branch}"
    echo "Git top level directory: ${git_root}"

    # Exit codes
     return 0   # No error
    #return 111 # Warning: continue processing plugins and apply version
    #return 112 # Error: continue processing plugins (to allow other generated errors) but stop before applying version
    #return 113 # Fatal error: stop immediately
}

case "${1}" in
    --about)
        echo -n "Example plugin."
        ;;
    *)
        run "$@"
        ;;
esac
