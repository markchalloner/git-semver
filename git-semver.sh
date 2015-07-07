#!/bin/bash

########################################
# Usage
########################################

usage() {
	cat <<-EOF
		Usage: $(basename $0 | tr '-' ' ' | sed 's/.sh$//g') [command]

		This script automates semantic versioning. Requires a valid change log at CHANGELOG.md.

		See https://github.com/markchalloner/git-semver for more detail.

		Commands
		 get        Gets the current version (tag)
		 major      Generates a tag for the next major version and echos it to the screen
		 minor      Generates a tag for the next minor version and echos it to the screen
		 patch|next Generates a tag for the next patch version and echos it to the screen
		 update     Check for updates and install if there are any available
		 help       This message

	EOF
	exit
}

########################################
# Helper functions
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

# Gets input from the console
# Takes a string message and optionally a string default (not shown if secure is set) and a boolean secure flag for passwords
#
# Example
#   $ get_input "Enter a password" "123456" true
#   Enter a password (defaults to 1234) (not visible):
#   $ password=${RETVAL}
#
function get_input() {
    local message=$1
    local default=$2
    local secure=$3
    local args="-r"
    local output=
    local msg_notvisible=
    local msg_default=
    if [ -n "${default}" ]
    then
        if [ "${secure}" = true ]
        then
            default_secure="unchanged"
        else
            default_secure=\"${default}\"
        fi
        msg_default=" (defaults to ${default_secure})"
    fi
    if [ "${secure}" = true ]
    then
        args="${args} -s"
        msg_notvisible=" (not visible)"
    fi
    while :
    do
        echo -n "${message}${msg_default}${msg_notvisible}: "
        read ${args} input
        if [ "${secure}" = true ]
        then
            echo
        fi
        if [ -n "${input}" ]
        then
            output=${input}
            break
        elif [ -n "${default}" ]
        then
            output=${default}
            break
        fi
    done
    RETVAL=${output}
}

# Resolves a path to a real path
# Takes a string path
#
# Example
#   $ echo $(resolve-path "/var/./www/../log/messages.log")
#   /var/log/messages.log
#
resolve-path() {
    local path="$1"
    if pushd "$path" > /dev/null 2>&1
    then
        path=$(pwd -P)
        popd > /dev/null
    elif [ -L "$path" ]
    then
        path="$(ls -l "$path" | sed 's#.* /#/#g')"
        path="$(resolve-path $(dirname "$path"))/$(basename "$path")"
    fi
    echo "$path"
}

########################################
# Update functions
########################################

update-force-enabled() {
    [ -n "${UPDATE_CHECK_FORCE}" ] && [ ${UPDATE_CHECK_FORCE} -eq 1 ]
    return $?
}

update-check() {
    local dir="$1"
    if [ -d "${dir}/.git" ]
    then
        (cd ${dir} && git fetch)
        local version=$(git tag | grep "^[0-9]\+\.[0-9]\+\.[0-9]\+$" | sort -t. -k 1,1n -k 2,2n -k 3,3n | tail -1)
        if update-force-enabled || [ $(git rev-list --left-right HEAD...${version} | grep "^>" | wc -l | sed 's/ //g') -gt 0 ]
        then
            echo ${version}
            return 0
        fi
    fi
    return 1
}

update-silent() {
    if [ "$1" != "${ARG_NOUPDATE}" ] && [ ${UPDATE_CHECK} -eq 1 ]
    then
        update true
    fi
}

update() {
    silent=$1
    local status=1

    local date_curr=$(date "+%Y-%m-%d")
    mkdir -p ${DIR_DATA}
    echo ${date_curr} > "${FILE_UPDATE}"

    if update-force-enabled
    then
        echo "Warning: Forcing update check (UPDATE_CHECK_FORCE=1)"
        UPDATE_CHECK_INTERVAL_DAYS=0
    fi

    if [ -n "$silent" ]
    then
        local time_curr=$(date -d "${date_curr}" "+%s")
        local time_prev=""
        local time_check=$((${time_curr} - ${UPDATE_CHECK_INTERVAL_DAYS} * 86400))
        if [ -f "${FILE_UPDATE}" ]
        then
            time_prev=$(date -d "$(cat ${FILE_UPDATE} | tr -d $'\n')" "+%s")
        else
            time_prev=${time_check}
        fi

        if [ ${time_check} -lt ${time_prev}  ]
        then
            return 1
        fi
    fi

    if ! $(which git > /dev/null)
    then
        if [ -z "$silent" ]
        then
            echo "Error: Unable to update - git is not installed"
        fi
        return 1
    fi

    local dir="$(dirname $(resolve-path "$0"))"
    if [ ! -d "${dir}/.git" ]
    then
        if [ -z "$silent" ]
        then
            echo "Error: Unable to update - cannot find git repository"
        fi
        return 1
    fi

    version=$(update-check "${dir}")
    if [ $? -gt 0 ]
    then
        if [ -z "$silent" ]
        then
            echo "No updates found"
        fi
        return 0
    fi

    get_input "New version ${version} found. Upgrade (y/n)?" "y"
    do_upgrade="${RETVAL}"
    if [ "${do_upgrade}" == "y" ]
    then
        (cd ${dir} && git checkout ${version})
        status=$?
    fi

    if [ -n "$silent" ] && [ ${status} -eq 0 ]
    then
        "$0" ${ARGS} ${ARG_NOUPDATE}
        exit
    fi

    return ${status}
}

########################################
# Changelog functions
########################################

changelog-check-enabled() {
    [ -n "${CHANGELOG_CHECK}" ] && [ ${CHANGELOG_CHECK} -eq 1 ]
    return $?
}

changelog-check() {
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
    local tag_prev=
    if [ "" == "$($0 get)" ]
    then
        require_link=0
        tag_grep="${tag}"
        tag_actual="${tag}"
    fi
    tag_grep="$(echo "${tag_grep}" | sed 's#\.#\\.#g')"

    if ! git show HEAD:${changelog} > /dev/null 2>&1
    then
        echo "Error: No changelog file found at ${root}/${changelog}"
        return 1
    fi

    local changelog_content=$(git show HEAD:${changelog})
    local changelog_tags=$(echo "${changelog_content}" | grep '^## \[\?[0-9]\+\.[0-9]\+\.[0-9]\]\? - ')

    if ! echo "${changelog_content}" | grep -q "^## ${tag_grep} - [0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}"
    then
        echo -e "Error: no changelog details found for ${tag}. Change log should be recorded in ${changelog} with the format\n\n## ${tag_actual} - YYYY-MM-DD\n### Added\n- Details...\n\nSee http://keepachangelog.com/ for full format\n"
        status=1
        tag_prev=$(echo "${changelog_tags}" | head -n 1 | sed 's/^## \[\?\([0-9]\+\.[0-9]\+\.[0-9]\)\]\?.*$/\1/g')
    else
        tag_prev=$(echo "${changelog_tags}" | head -n 2 | tail -n 1 | sed 's/^## \[\?\([0-9]\+\.[0-9]\+\.[0-9]\)\]\?.*$/\1/g')
    fi

    if ! echo "${changelog_content}" | grep -q "^\[unreleased\]: ${compareurl}/${tag}\.\.\.HEAD$"
    then
        #echo -e "Error: no changelog link for unreleased. Please update the unreleased link at the bottom of the changelog to: \n\n[unreleased]: ${compareurl}/${tag}...HEAD\n"
        update_links_desc+=("unreleased")
        update_links_line+=("[unreleased]: ${compareurl}/${tag}...HEAD")
        update_links=1
    fi

    if [ ${require_link} -eq 1 ] && ! echo "${changelog_content}" | grep -q "^\[${tag}\]: ${compareurl}/${tag_prev}\.\.\.${tag}$"
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

########################################
# Version functions
########################################

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
    if ! changelog-check-enabled || changelog-check $new
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
    if ! changelog-check-enabled || changelog-check $new
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
    if ! changelog-check-enabled || changelog-check $new
    then
        git tag $new && echo $new
    fi
}

########################################
# Run
########################################

# Set default config
UPDATE_CHECK=1
UPDATE_CHECK_INTERVAL_DAYS=1

# Load user config
if [ -f "${HOME}/.git-semver/config" ]
then
    source "${HOME}/.git-semver/config"
fi

# Set vars
DIR_DATA=${HOME}/.git-semver
FILE_CONF="${DIR_DATA}/config"
FILE_UPDATE="${DIR_DATA}/update"

ARGS=$@
ARG_NOUPDATE=noupdate
for ARG_LAST; do true; done

case "$1" in
    get)
        update-silent ${ARG_LAST}
        version-get
        ;;
    major)
        update-silent ${ARG_LAST}
        version-major
        ;;
    minor)
        update-silent ${ARG_LAST}
        version-minor
        ;;
    patch|next)
        update-silent ${ARG_LAST}
        version-patch
        ;;
    update)
        update
        ;;
    help)
        usage
        ;;
    *)
        usage
        ;;
esac
