#!/bin/bash

function run() {

    local version_new="$1"

    local minor_number=$(echo "$version_new" | cut --delimiter="." --fields=2)
    local major_number=$(echo "$version_new" | cut --delimiter="." --fields=1)

    minor_tag="$major_number"."$minor_number"
    if git tag --list | grep -xq "$minor_tag"
    then
        echo "Recreating minor tag $minor_tag"
        git tag --delete "$minor_tag"
    else
        echo "Creating minor tag $minor_tag"
    fi
    git tag "$minor_tag"

    if git tag --list | grep -xq "$major_number"
    then
        echo "Recreating major tag $major_number"
        git tag --delete "$major_number"
    else
        echo "Creating major tag ""$major_number"
    fi
    git tag "$major_number"

    echo

    return 0
}

case "${1}" in
    --about)
        echo -n "Create or recreate a minor and major tag on each version bump."
        ;;
    *)
        run "$@"
        ;;
esac

