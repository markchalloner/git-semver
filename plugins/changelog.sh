#!/bin/bash

function run
{
    local version_current="$1"
    local version_previous="$2"
    local git_hash="$3"
    local git_branch="$4"
    local git_root="$5"

    local changelog=${git_root}/CHANGELOG.md

    #local tag=$1
    #local root=$(git rev-parse --show-toplevel)
    local origin=$(git config --get remote.origin.url | sed 's#^\([^@]\+@\|https\?://\)\([^:/]\+\)[:/]\([^\.]\+\)\..*$#\2/\3#g')
    local compareurl=https://${origin}/compare
    #local changelog=CHANGELOG.md
    local status=0
    local update_links_desc=()
    local update_links_line=()
    local update_links=0

    # If there is no existing tag relax rules slightly
    local require_link=1
    local tag_grep="\[${tag}\]"
    local tag_actual="[${tag}]"
    if [ "" == "$($0 get)" ]
    then
        require_link=0
        tag_grep="${tag}"
        tag_actual="${tag}"
    fi

    if ! git show HEAD:${changelog} > /dev/null 2>&1
    then
        echo "Error: No changelog file found at ${root}/${changelog}"
        return 1
    fi

    local tag_prev=$(git show HEAD:CHANGELOG.md | grep '^## \[\?[0-9]\+\.[0-9]\+\.[0-9]\]\? - ' | head -n 2 | tail -n 1 | sed 's/^## \[\?\([0-9]\+\.[0-9]\+\.[0-9]\)\]\?.*$/\1/g')

    if ! git show HEAD:${changelog} | grep -q "^## ${tag_grep} - [0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}"
    then
        echo -e "Error: no changelog details found for ${tag}. Change log should be recorded in ${changelog} with the format\n\n## ${tag_actual} - YYYY-MM-DD\n### Added\n- Details...\n\nSee http://keepachangelog.com/ for full format\n"
        status=1
    fi

    if ! git show HEAD:${changelog} | grep -q "^\[unreleased\]: ${compareurl}/${tag}\.\.\.HEAD$"
    then
        #echo -e "Error: no changelog link for unreleased. Please update the unreleased link at the bottom of the changelog to: \n\n[unreleased]: ${compareurl}/${tag}...HEAD\n"
        update_links_desc+=("unreleased")
        update_links_line+=("[unreleased]: ${compareurl}/${tag}...HEAD")
        update_links=1
    fi

    if [ ${require_link} -eq 1 ] && ! git show HEAD:${changelog} | grep -q "^\[${tag}\]: ${compareurl}/${tag_prev}\.\.\.${tag}$"
    then
        #echo -e "Error: no changelog link for ${tag}. Please add the ${tag} link at the bottom of the changelog: \n\n[${tag}]: ${compareurl}/${tag_prev}...${tag}\n"
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
        echo -e "Error: no changelog ${links} for ${update_links_descs}. Please add the ${update_links_descs} ${links} at the bottom of the changelog: \n\n${update_links_lines}\n"
        status=1
    fi

    if [ ${status} -eq 1 ] && [ $(git rev-list --left-right @{u}... | grep "^>" | wc -l | sed 's/ //g') -gt 0 ]
    then
        echo -e "After making these changes, you can add your change log to your latest unpublished commit by running:\n\ngit add ${changelog}\ngit commit --amend -m '$(git log -1 --pretty=%B)'\n"
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
