#!/bin/bash
# 

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

check-changelog() {
    local tag=$1
    local root=$(git rev-parse --show-toplevel)
    local origin=$(git config --get remote.origin.url | sed 's/^[^:]\+://g' | sed 's/\.git$//g')
    local compareurl=https://github.com/${origin}/compare
    local changelog=CHANGELOG.md

    # Check if there is an existing tag and relax rules if not
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
    
    local tag_prev=$(git show HEAD:${changelog} | grep "^\[[0-9]\+\.[0-9]\+\.[0-9]\+\]: ${compareurl}" | grep -v "^\[${tag}\]" | head -n 1 | sed 's/^\[\([^]]\+\)\].*/\1/g')
    
    if ! git show HEAD:${changelog} | grep -q "^## ${tag_grep} - [0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}"
    then
        echo -e "Error: no changelog details found for ${tag}. Change log should be recorded in ${changelog} with the format\n\n## ${tag_actual} - YYYY-MM-DD\n### Added\n- Details...\n\nSee http://keepachangelog.com/ for full format"
        return 1
    fi
    if ! git show HEAD:${changelog} | grep -q "^\[unreleased\]: ${compareurl}/${tag}\.\.\.HEAD$"
    then
        echo -e "Error: no changelog link for unreleased. Please update the unreleased link at the bottom of the changelog to: \n\n[unreleased]: ${compareurl}/${tag}...HEAD\n"
        return 1
    fi
    if [ ${require_link} -eq 1 ] && ! git show HEAD:${changelog} | grep -q "^\[${tag}\]: ${compareurl}/${tag_prev}\.\.\.${tag}$"
    then
        echo -e "Error: no changelog link for ${tag}. Please add the ${tag} link at the bottom of the changelog: \n\n[${tag}]: ${compareurl}/${tag_prev}...${tag}\n"
        return 1
    fi
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
	local version=$(git tag | grep "^[0-9]\+\.[0-9]\+\.[0-9]\+$" | sort -V | tail -1)
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
