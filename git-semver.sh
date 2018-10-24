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
		 get                                                   Gets the current version (tag)
		 major [--dryrun] [-p <pre-release>] [-b <build>]      Generates a tag for the next major version and echos to the screen
		 minor [--dryrun] [-p [<pre-release> [-b <build>]      Generates a tag for the next minor version and echos to the screen
		 patch|next [--dryrun] [-p <pre-release>] [-b <build>] Generates a tag for the next patch version and echos to the screen
		 pre-release [--dryrun] -p <pre-release> [-b <build>]  Generates a tag for a pre-release version and echos to the screen
		 build [--dryrun] -b <build>                           Generates a tag for a build and echos to the screen
		 help                                                  This message

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

validate-pre-release() {
    local pre_release=$1
    if ! [[ "$pre_release" =~ ^[0-9A-Za-z.-]*$ ]] || # Not alphanumeric, `-` and `.`
        [[ "$pre_release" =~ (^|\.)\. ]] ||          # Empty identifiers
        [[ "$pre_release" =~ \.(\.|$) ]] ||          # Empty identifiers
        [[ "$pre_release" =~ \.0[0-9] ]]             # Leading zeros
    then
        echo "Error: pre-release is not valid."
        exit 1
    fi
}

validate-build() {
    local build=$1
    if ! [[ "$build" =~ ^[0-9A-Za-z.-]*$ ]] || # Not alphanumeric, `-` and `.`
        [[ "$build" =~ (^|\.)\. ]] ||          # Empty identifiers
        [[ "$build" =~ \.(\.|$) ]]             # Empty identifiers
    then
        echo "Error: build metadata is not valid."
        exit 1
    fi
}

########################################
# Version functions
########################################

version-parse-major() {
    echo "$1" | cut -d "." -f1 | sed "s/^${VERSION_PREFIX}//g"
}

version-parse-minor() {
    echo "$1" | cut -d "." -f2
}

version-parse-patch() {
    echo "$1" | cut -d "." -f3 | sed 's/[-+].*$//g'
}

version-parse-pre-release() {
    echo "$1" | cut -d "." -f3 | grep -o '\-[0-9A-Za-z.]\+'
}

version-get() {
    local sort_args version version_pre_releases pre_release_id_count pre_release_id_index
    local tags=$(git tag)
    local version_pre_release=$(
        local version_main=$(
            echo "$tags" |
                grep "^${VERSION_PREFIX}[0-9]\+\.[0-9]\+\.[0-9]\+" |
                awk -F '[-+]' '{ print $1 }' |
                uniq |
                sort -t '.' -k 1,1n -k 2,2n -k 3,3n |
                tail -n 1
        )
        local version_pre_releases=$(
            echo "$tags" |
                grep "^${version_main//./\\.}" |
                awk -F '-' '{ print $2 }'
        )
        local pre_release_id_count=$(
            echo "$version_pre_releases" | tr -d -c ".\n" |
                awk 'BEGIN{ max = 0 }
                { if (max < length) { max = length } }
                END{ if ( max == 0 ) { print 0 } else { print max + 1 } }'
        )
        local sort_args='-t.'
        for ((pre_release_id_index=1; pre_release_id_index<=$pre_release_id_count; pre_release_id_index++))
        do
            chars="$(echo "$version_pre_releases" | awk -F '.' '{ print $'$pre_release_id_index' }' | tr -d $'\n')"
            if [[ "$chars" =~ ^[0-9]*$ ]]
            then
                sort_key_type=n
            else
                sort_key_type=
            fi
            sort_args="$sort_args -k$pre_release_id_index,$pre_release_id_index$sort_key_type"
        done
        echo "$version_pre_releases" |
            eval sort $sort_args |
            awk '{ if (length == 0) { print "'$version_main'" } else { print "'$version_main'-"$1 } }' |
            tail -n 1
    )
    # Get the version with the build number
    version=$(echo "$tags" | grep "^${version_pre_release//./\\.}" | tail -n 1)
    if [ "" == "${version}" ]
    then
        return 1
    else
        echo "${version}"
    fi
}

version-major() {
    local pre_release=${1:+-$1}
    local build=${2:++$2}
    # shellcheck disable=SC2155
    local version=$(version-get)
    # shellcheck disable=SC2155
    local major=$(version-parse-major "${version}")
    if [ "" == "$version" ]
    then
        local new=${VERSION_PREFIX}1.0.0${pre_release}${build}
    else
        local new=${VERSION_PREFIX}$((major+1)).0.0${pre_release}${build}
    fi
    version-do "$new" "$version"
}

version-minor() {
    local pre_release=${1:+-$1}
    local build=${2:++$2}
    # shellcheck disable=SC2155
    local version=$(version-get)
    # shellcheck disable=SC2155
    local major=$(version-parse-major "${version}")
    # shellcheck disable=SC2155
    local minor=$(version-parse-minor "${version}")
    if [ "" == "$version" ]
    then
        local new=${VERSION_PREFIX}0.1.0${pre_release}${build}
    else
        local new=${VERSION_PREFIX}${major}.$((minor+1)).0${pre_release}${build}
    fi
    version-do "$new" "$version"
}

version-patch() {
    local pre_release=${1:+-$1}
    local build=${2:++$2}
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
        local new=${VERSION_PREFIX}0.1.0${pre_release}${build}
    else
        local new=${VERSION_PREFIX}${major}.${minor}.$((patch+1))${pre_release}${build}
    fi
    version-do "$new" "$version"
}

version-pre-release() {
    local pre_release=$1
    local build=${2:++$2}
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
        local new=${VERSION_PREFIX}0.1.0-${pre_release}${build}
    else
        local new=${VERSION_PREFIX}${major}.${minor}.${patch}-${pre_release}${build}
    fi
    version-do "$new" "$version"
}

version-build() {
    local build=$1
    # shellcheck disable=SC2155
    local version=$(version-get)
    # shellcheck disable=SC2155
    local major=$(version-parse-major "${version}")
    # shellcheck disable=SC2155
    local minor=$(version-parse-minor "${version}")
    # shellcheck disable=SC2155
    local patch=$(version-parse-patch "${version}")
    # shellcheck disable=SC2155
    local pre_release=$(version-parse-pre-release "${version}")
    if [ "" == "$version" ]
    then
        local new=${VERSION_PREFIX}0.1.0${pre_release}+${build}
    else
        local new=${VERSION_PREFIX}${major}.${minor}.${patch}${pre_release}+${build}
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
    if [ $dryrun == 1 ]
    then
        echo "$new"
    elif plugin-run "$new" "$version"
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

# Set vars
DIR_ROOT="$(git rev-parse --show-toplevel 2> /dev/null)"

# Set (and load) user config
if [ -f "${DIR_ROOT}/.git-semver" ]
then
    FILE_CONF="${DIR_ROOT}/.git-semver"
    source "${FILE_CONF}"
elif [ -f "${DIR_CONF}/config" ]
then
    FILE_CONF="${DIR_CONF}/config"
    # shellcheck source=config.example
    source "${FILE_CONF}"
else
    # No existing config file was found; use default
    FILE_CONF="${DIR_HOME}/.git-semver/config"
fi

GIT_HASH="$(git rev-parse HEAD 2> /dev/null)"
GIT_BRANCH="$(git rev-parse --abbrev-ref HEAD 2> /dev/null)"

# Parse args
action=
build=
pre_release=
dryrun=0
while :
do
    case "$1" in
        -d)
            dryrun=1
            ;;
        --dryrun)
            dryrun=1
            ;;
        -b)
            build=$2
            shift
            validate-build "$build"
            ;;
        -p)
            pre_release=$2
            shift
            validate-pre-release "$pre_release"
            ;;
        ?*)
            action=$1
            ;;
        *)
            break
            ;;
    esac
    shift
done

case "$action" in
    get)
        version-get
        ;;
    major)
        version-major "$pre_release" "$build"
        ;;
    minor)
        version-minor "$pre_release" "$build"
        ;;
    patch|next)
        version-patch "$pre_release" "$build"
        ;;
    pre-release)
        [ -n "$pre_release" ] || usage
        version-pre-release "$pre_release" "$build"
        ;;
    build)
        [ -n "$build" ] || usage
        version-build "$build"
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
