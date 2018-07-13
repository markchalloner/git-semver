#!/bin/bash

file="CHANGELOG.md"

function run() {
    # Error: continue processing plugins (to allow other generated errors) but stop before applying version tag
    local error=112

    local version_new="$1"
    local version_current="$2"
    local git_root="$5"

    local status=0
    local git_origin=$(git config --get remote.origin.url | sed 's#^\([^@]\+@\|https\?://\)\([^:/]\+\)[:/]\([^\.]\+\)\..*$#\2/\3#g')
    local git_compare=https://${git_origin}/compare

    local update_links_desc=()
    local update_links_line=()
    local update_links=0

    local require_link=1
    local version_new_grep="\[${version_new}\]"
    local version_new_actual="[${version_new}]"
    local version_previous=

    # If there is no existing version relax rules slightly
    if [ "" == "${version_current}" ]
    then
        require_link=0
        version_new_grep="${version_new}"
        version_new_actual="${version_new}"
    fi
    version_new_grep="$(echo "${version_new_grep}" | sed 's#\.#\\.#g')"

    local format="## ${version_new_actual} - $(date +%Y-%m-%d)\n### Added\n- ...\n\nSee http://keepachangelog.com/ for full format."

    if ! git show HEAD:${file} > /dev/null 2>&1
    then
        echo "Error: No ${file} file committed at \"${git_root}/${file}\""
        return ${error}
    fi

    local file_content=$(git show HEAD:${file})
    local file_versions=$(echo "${file_content}" | grep '^## \[\?[0-9]\+\.[0-9]\+\.[0-9]\]\? - ')

    if ! echo "${file_content}" | grep -q "^## ${version_new_grep} - [0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}"
    then
        echo -e "Error: no changelog details found for ${version_new}. Changelog details should be recorded in ${file} with the format:\n"
        echo -e "${format}"
        status=1
        version_previous=$(echo "${file_versions}" | head -n 1 | sed 's/^## \[\?\([0-9]\+\.[0-9]\+\.[0-9]\)\]\?.*$/\1/g')
    else
        version_previous=$(echo "${file_versions}" | head -n 2 | tail -n 1 | sed 's/^## \[\?\([0-9]\+\.[0-9]\+\.[0-9]\)\]\?.*$/\1/g')
    fi

    if ! echo "${file_content}" | grep -q "^\[unreleased\]: ${git_compare}/${version_new}\.\.\.HEAD$"
    then
        update_links_desc+=("unreleased")
        update_links_line+=("[unreleased]: ${git_compare}/${version_new}...HEAD")
        update_links=1
    fi

    if [ ${require_link} -eq 1 ] && ! echo "${file_content}" | grep -q "^\[${version_new}\]: ${git_compare}/${version_previous}\.\.\.${version_new}$"
    then
        update_links_desc+=("version ${version_new}")
        update_links_line+=("[${version_new}]: ${git_compare}/${version_previous}...${version_new}")
        update_links=1
    fi

    if [ ${update_links} -eq 1 ]
    then
        local update_links_descs=$(join " and " "${update_links_desc[@]}")
        local update_links_lines=$(join $'\n' "${update_links_line[@]}")
        local links="link"
        if [ ${#update_links_desc[@]} -gt 1 ]
        then
            links+="s"
        fi
        echo -e "\nError: no ${links} for ${update_links_descs}. Please add the ${update_links_descs} ${links} at the bottom of the changelog:\n"
        echo -e "${update_links_lines}"
        status=${error}
    fi
    if [ ${status} -eq 1 ] && git rev-list @{u}... > /dev/null 2>&1 && [ $(git rev-list --left-right @{u}... | grep "^>" | wc -l | sed 's/ //g') -gt 0 ]
    then
        echo -e "\nAfter making these changes, you can add your change log to your latest unpublished commit by running:\n\ngit add ${file}\ngit commit --amend -m '$(git log -1 --pretty=%B)'"
    fi

    return ${status}
}

function join() {
    local separator=$1
    local elements=$2
    shift 2 || shift $(($#))
    printf "%s" "$elements${@/#/$separator}"
}

case "${1}" in
    --about )
        echo -n "Check ${file} has been updated."
        ;;
    * )
        run "$@"
        ;;
esac
