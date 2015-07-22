#!/bin/bash

# Joins elements in an array with a separator
# Takes a separator and array of elements to join
#
# Adapted from code by gniourf_gniourf (http://stackoverflow.com/a/23673883/1819350)
#
# Example
#   $ arr=("red car" "blue bike")
#   $ join " and " "${arr[@]}"
#   red car and blue bike
#   $ join $'\n' "${arr[@]}"
#   red car
#   blue bike
#
function join() {
    local separator=$1
    local elements=$2
    shift 2 || shift $(($#))
    printf "%s" "$elements${@/#/$separator}"
}

function run
{
    # Compulsory error: continue processing plugins (to allow other generated errors) but stop before applying version tag
    local error=112

    local tag="$1"
    local tag_curr="$2"
    local root="$5"
    local origin=$(git config --get remote.origin.url | sed 's#^\([^@]\+@\|https\?://\)\([^:/]\+\)[:/]\([^\.]\+\)\..*$#\2/\3#g')
    local compareurl=https://${origin}/compare
    local changelog=CHANGELOG.md
    local status=0
    local update_links_desc=()
    local update_links_line=()
    local update_links=0

    # If there is no existing tag relax rules slightly
    local require_link=1
    local tag_grep="\[${tag}\]"
    local tag_actual="[${tag}]"
    local tag_prev=
    if [ "" == "${tag_curr}" ]
    then
        require_link=0
        tag_grep="${tag}"
        tag_actual="${tag}"
    fi
    tag_grep="$(echo "${tag_grep}" | sed 's#\.#\\.#g')"

    if ! git show HEAD:${changelog} > /dev/null 2>&1
    then
        echo "Error: No changelog file found at ${root}/${changelog}"
        return ${error}
    fi

    local changelog_content=$(git show HEAD:${changelog})
    local changelog_tags=$(echo "${changelog_content}" | grep '^## \[\?[0-9]\+\.[0-9]\+\.[0-9]\]\? - ')

    if ! echo "${changelog_content}" | grep -q "^## ${tag_grep} - [0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}"
    then
        echo -e "Error: no changelog details found for ${tag}. Change log should be recorded in ${changelog} with the format:\n\n## ${tag_actual} - $(date +%Y-%m-%d)\n### Added\n- ...\n\nSee http://keepachangelog.com/ for full format."
        status=1
        tag_prev=$(echo "${changelog_tags}" | head -n 1 | sed 's/^## \[\?\([0-9]\+\.[0-9]\+\.[0-9]\)\]\?.*$/\1/g')
    else
        tag_prev=$(echo "${changelog_tags}" | head -n 2 | tail -n 1 | sed 's/^## \[\?\([0-9]\+\.[0-9]\+\.[0-9]\)\]\?.*$/\1/g')
    fi

    if ! echo "${changelog_content}" | grep -q "^\[unreleased\]: ${compareurl}/${tag}\.\.\.HEAD$"
    then
        update_links_desc+=("unreleased")
        update_links_line+=("[unreleased]: ${compareurl}/${tag}...HEAD")
        update_links=1
    fi

    if [ ${require_link} -eq 1 ] && ! echo "${changelog_content}" | grep -q "^\[${tag}\]: ${compareurl}/${tag_prev}\.\.\.${tag}$"
    then
        update_links_desc+=("version ${tag}")
        update_links_line+=("[${tag}]: ${compareurl}/${tag_prev}...${tag}")
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
        echo -e "\nError: no changelog ${links} for ${update_links_descs}. Please add the ${update_links_descs} ${links} at the bottom of the changelog: \n\n${update_links_lines}"
        status=${error}
    fi
    if [ ${status} -eq 1 ] && git rev-list @{u}... > /dev/null 2>&1 && [ $(git rev-list --left-right @{u}... | grep "^>" | wc -l | sed 's/ //g') -gt 0 ]
    then
        echo -e "\nAfter making these changes, you can add your change log to your latest unpublished commit by running:\n\ngit add ${changelog}\ngit commit --amend -m '$(git log -1 --pretty=%B)'"
    fi

    return ${status}
}

case "${1}" in
    --about )
        echo -n "Check changelog has been updated along with code."
        ;;
    * )
        run "$@"
        ;;
esac
