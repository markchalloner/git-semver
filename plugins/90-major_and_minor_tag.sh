#!/bin/bash

function run() {

    local version_new="$1"

    local minor_number=$(echo "$version_new" | cut --delimiter="." --fields=2)
    local major_number=$(echo "$version_new" | cut --delimiter="." --fields=1)

    if git tag --list | grep -xq "$major_number"".""$minor_number"
    then
        echo "Recreating minor tag ""$major_number"".""$minor_number"
        git tag --delete "$major_number"".""$minor_number"
    else
        echo "Creating minor tag ""$major_number"".""$minor_number"
    fi
    git tag "$major_number"".""$minor_number"

    if git tag --list | grep -xq "$major_number"
    then
        echo "Recreating major tag ""$major_number"
        git tag --delete "$major_number"
    else
        echo "Creating major tag ""$major_number"
    fi
    git tag "$major_number"

    return 0
}

case "${1}" in
    --about)
        echo -n "Example plugin."
        ;;
    *)
        run "$@"
        ;;
esac

