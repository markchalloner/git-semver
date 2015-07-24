#!/bin/bash

file="package.json"

function run() {
    # Compulsory error: continue processing plugins (to allow other generated errors) but stop before applying version tag
    local error=112

    local version_new="$1"
    local version_current="$2"
    local git_root="$5"

    local status=0
    local version_new_grep=$(echo ${version_new} | sed 's/\./\\\./g')

    local format="\"version\": \"${version_new}\","

    if ! git show HEAD:${file} > /dev/null 2>&1
    then
        echo "Error: No ${file} file committed at \"${git_root}/${file}\""
        return ${error}
    fi

    local file_content=$(git show HEAD:${file})

    if ! echo "${file_content}" | grep -q "^[ \t]*\\\"\?version\\\"\?[ \t]*:[ \t]*\\\"${version_new_grep}\\\""
    then
        echo -e "Error: Version ${version_new} not found in ${file}. Version should be recorded in the format:\n"
        echo -e "${format}"
        status=${error}
    fi

    if [ ${status} -ne 0 ] && git rev-list @{u}... > /dev/null 2>&1 && [ $(git rev-list --left-right @{u}... | grep "^>" | wc -l | sed 's/ //g') -gt 0 ]
    then
        echo -e "\nAfter making these changes, you can add your ${file} file to your latest unpublished commit by running:\n\ngit add \"${file}\"\ngit commit --amend -m '$(git log -1 --pretty=%B)'"
    fi

    return ${status}
}

case "${1}" in
    --about)
        echo -n "Check ${file} has been updated."
        ;;
    *)
        run "$@"
        ;;
esac
