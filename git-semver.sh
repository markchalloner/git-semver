#!/bin/bash

########################################
# Usage
########################################

usage() {
	cat <<-EOF
		Usage: $(basename $0 | tr '-' ' ') [command]

		This script automates semantic versioning. Requires a valid change log at CHANGELOG.md.

		See https://github.com/markchalloner/git-semver for more detail.

		Commands
		 help       This message
		 get        Gets the current version (tag)
		 major      Generates a tag for the next major version and echos it to the screen
		 minor      Generates a tag for the next minor version and echos it to the screen
		 patch|next Generates a tag for the next patch version and echos it to the screen
		 
	EOF
	exit
}

########################################
# Functions
########################################

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
join() {
    local separator=$1 
    local elements=$2
    shift 2 || shift $(($#))
    printf "%s" "$elements${@/#/$separator}"
}

check-update(){
    local dir_self=$(dirname realpath $0)
    if $(which git) && [ -d "${dir_self}/.git" ]
    then
        (cd $dir_self && git fetch)
        local version=$(git tag | grep "^[0-9]\+\.[0-9]\+\.[0-9]\+$" | sort -t. -k 1,1n -k 2,2n -k 3,3n | tail -1)
        if [ $(git rev-list --left-right HEAD...${version} | grep "^>" | wc -l | sed 's/ //g') -gt 0 ]
        then
            local do_upgrade=get_user_input "Version ${version} has been released. Would you like to upgrade (y/n)?" "y"
            if [ "${do_upgrade}" == "y" ]
            then
                git checkout ${version}
            fi
        fi
    fi
}

check-changelog() {
    local tag=$1
    local root=$(git rev-parse --show-toplevel)
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

version-parse() {
    echo $1 | sed 's#^\([0-9]\+\)\.\([0-9]\+\)\.\([0-9]\+\)$#\1 \2 \3#g'
}

version-parse-major() {
    local version=($(version-parse $1))
    echo ${version[0]}
}

version-parse-minor() {
    local version=($(version-parse $1))
    echo ${version[1]}
}

version-parse-patch() {
    local version=($(version-parse $1))
    echo ${version[2]}
}

version-get() {
	local version=$(git tag | grep "^[0-9]\+\.[0-9]\+\.[0-9]\+$" | sort -t. -k 1,1n -k 2,2n -k 3,3n | tail -1)
        if [ "" == "$version" ]
        then
            return 1
        else
            echo $version
        fi
}

version-major() {
    local version=$(version-get)
    local major=$(version-parse-major ${version})
    if [ "" == "$version" ]
    then
        local new=1.0.0
    else
        local new=$((${major} + 1)).0.0
    fi
    if check-changelog $new
    then
        git tag $new && echo $new
    fi
}

version-minor() {
    local version=$(version-get)
    local major=$(version-parse-major ${version})
    local minor=$(version-parse-minor ${version})
    if [ "" == "$version" ]
    then
        local new=0.1.0
    else
        local new=${major}.$((${minor} + 1)).0
    fi
    if check-changelog $new
    then
        git tag $new && echo $new
    fi
}

version-patch() {
    local version=$(version-get)
    local major=$(version-parse-major ${version})
    local minor=$(version-parse-minor ${version})
    local patch=$(version-parse-patch ${version})
    if [ "" == "$version" ]
    then
        local new=0.1.0
    else
        local new=${major}.${minor}.$(($patch + 1))
    fi
    if check-changelog $new
    then
        git tag $new && echo $new
    fi
}

########################################
# Run
########################################

case "$1" in
    get)
        version-get
        ;;
    major)
        version-major
        ;;    
    minor)
        version-minor
        ;;
    patch|next)
        version-patch
        ;;
    help)
        usage
        break
        ;;
    *)
        usage
        break
        ;;
esac
