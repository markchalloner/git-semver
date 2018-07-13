#!/bin/bash
########################################
# Usage
########################################

usage() {
	cat <<-EOF
		Usage: $(basename-git "$0") [command]

		This script automates semantic versioning. Requires a valid change log at CHANGELOG.md.

		See https://github.com/markchalloner/git-semver for more detail.

		Commands
		 get        Gets the current version (tag)
		 major      Generates a tag for the next major version and echos it to the screen
		 minor      Generates a tag for the next minor version and echos it to the screen
		 patch|next Generates a tag for the next patch version and echos it to the screen
		 help       This message

	EOF
	exit
}

########################################
# Helper functions
########################################

function basename-git() {
    basename "$1" | tr '-' ' ' | sed 's/.sh$//g'
}

########################################
# Plugin functions
########################################

plugin-output() {
    local type="$1"
    local name="$2"
    local output=
    while IFS='' read -r line
    do
        if [ -z "${output}" ]
        then
            echo -e "\n$type plugin \"$name\":\n"
            output=1
        fi
        echo "  $line"
    done
}

plugin-list() {
    local types=("User" "Project")
    local dirs=("${DIR_HOME}" "${DIR_ROOT}")
    local plugin_dir=
    local plugin_type=
    local total=${#dirs[*]}
    for (( i=0; i <= $((total-1)); i++ ))
    do
        plugin_type=${types[${i}]}
        plugin_dir="${dirs[${i}]}/.git-semver/plugins"
        if [ -d "${plugin_dir}" ]
        then
            find "${plugin_dir}" -maxdepth 1 -type f -exec echo "${plugin_type},{}" \;
        fi
    done
}

plugin-run() {
    # shellcheck disable=SC2155
    local plugins="$(plugin-list)"
    local version_new="$1"
    local version_current="$2"
    local status=0
    local type=
    local typel=
    local path=
    local name=
    for i in ${plugins}
    do
        type=${i%%,*}
        typel=$(echo "${type}" | tr '[:upper:]' '[:lower:]')
        path=${i##*,}
        name=$(basename "${path}")
        ${path} "${version_new}" "${version_current}" "${GIT_HASH}" "${GIT_BRANCH}" "${DIR_ROOT}" 2>&1 |
            plugin-output "${type}" "${name}"
        RETVAL=${PIPESTATUS[0]}
        case ${RETVAL} in
            0)
                ;;
            111|1)
                echo -e "\nError: Warning from ${typel} plugin \"${name}\", ignoring"
                ;;
            112)
                echo -e "\nError: Error from ${typel} plugin \"${name}\", unable to version"
                status=1
                ;;
            113)
                echo -e "\nError: Fatal error from ${typel} plugin \"${name}\", unable to version, quitting immediately"
                return 1
                ;;
            *)
                echo -e "\nError: Unknown error from ${typel} plugin \"${name}\", ignoring"
        esac
    done
    return ${status}
}

plugin-debug() {
    # shellcheck disable=SC2155
    local version=$(version-get)
    # shellcheck disable=SC2155
    local major=$(version-parse-major "${version}")
    # shellcheck disable=SC2155
    local minor=$(version-parse-minor "${version}")
    # shellcheck disable=SC2155
    local patch=$(version-parse-patch "${version}")
    if [ "" == "$version" ]
    then
        local new=0.1.0
    else
        local new=${major}.${minor}.$((patch+1))
    fi
    plugin-run "$new" "$version"
}

########################################
# Version functions
########################################

version-parse-major() {
    echo "$1" | cut -d "." -f1
}

version-parse-minor() {
    echo "$1" | cut -d "." -f2
}

version-parse-patch() {
    echo "$1" | cut -d "." -f3
}

version-get() {
    # shellcheck disable=SC2155
    local version=$(git tag | grep "^${VERSION_PREFIX}[0-9]\+\.[0-9]\+\.[0-9]\+$" | sed "s/^${VERSION_PREFIX}//" | sort -t. -k 1,1n -k 2,2n -k 3,3n | tail -1)
    if [ "" == "${version}" ]
    then
        return 1
    else
        echo "${version}"
    fi
}

version-major() {
    # shellcheck disable=SC2155
    local version=$(version-get)
    # shellcheck disable=SC2155
    local major=$(version-parse-major "${version}")
    if [ "" == "$version" ]
    then
        local new=${VERSION_PREFIX}1.0.0
    else
        local new=${VERSION_PREFIX}$((major+1)).0.0
    fi
    version-do "$new" "$version"
}

version-minor() {
    # shellcheck disable=SC2155
    local version=$(version-get)
    # shellcheck disable=SC2155
    local major=$(version-parse-major "${version}")
    # shellcheck disable=SC2155
    local minor=$(version-parse-minor "${version}")
    if [ "" == "$version" ]
    then
        local new=${VERSION_PREFIX}0.1.0
    else
        local new=${VERSION_PREFIX}${major}.$((minor+1)).0
    fi
    version-do "$new" "$version"
}

version-patch() {
    # shellcheck disable=SC2155
    local version=$(version-get)
    # shellcheck disable=SC2155
    local major=$(version-parse-major "${version}")
    # shellcheck disable=SC2155
    local minor=$(version-parse-minor "${version}")
    # shellcheck disable=SC2155
    local patch=$(version-parse-patch "${version}")
    if [ "" == "$version" ]
    then
        local new=${VERSION_PREFIX}0.1.0
    else
        local new=${VERSION_PREFIX}${major}.${minor}.$((patch+1))
    fi
    version-do "$new" "$version"
}

version-do() {
    local new="$1"
    local version="$2"
    local sign="${GIT_SIGN:-0}"
    local cmd="git tag"
    if [ "$sign" == "1" ]
    then
        cmd="$cmd -as -m $new"
    fi
    if plugin-run "$new" "$version"
    then
        $cmd "$new" && echo "$new"
    fi
}

########################################
# Run
########################################

# Set home
readonly DIR_HOME="${HOME}"

# Use XDG Base Directories if possible
# (see http://standards.freedesktop.org/basedir-spec/basedir-spec-latest.html)
DIR_CONF="${XDG_CONFIG_HOME:-${HOME}}/.git-semver"

# Set (and load) user config
if [ -f "${DIR_CONF}/config" ]
then
    FILE_CONF="${DIR_CONF}/config"
    # shellcheck source=config.example
    source "${FILE_CONF}"
else
    # No existing config file was found; use default
    FILE_CONF="${DIR_HOME}/.git-semver/config"
fi

# Set vars
DIR_ROOT="$(git rev-parse --show-toplevel 2> /dev/null)"

GIT_HASH="$(git rev-parse HEAD 2> /dev/null)"
GIT_BRANCH="$(git rev-parse --abbrev-ref HEAD 2> /dev/null)"

# Set $1 to last argument.
for _; do true; done

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
    debug)
        plugin-debug
        ;;
    help)
        usage
        ;;
    *)
        usage
        ;;
esac
