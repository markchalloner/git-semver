#!/bin/bash

shopt -s extglob nullglob

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
		 update     Check for updates and install if there are any available
		 help       This message

	EOF
	exit
}

########################################
# Helper functions
########################################

# Gets the index of the string to search
# Takes a search string and an array of elements to join (as arguments)
#
# Example
#   $ arr=("red" "blue")
#   $ echo $(index "blue" "${arr[@]}" )
#   1
#
function index() {
    local c=0;
    local needle="$1"
    shift
    local haystack="$@"
    for i in ${haystack}
    do
        if [ "${i}" = "${needle}" ]
        then
            echo "$c"
            return 0
        fi
        : $((c++))
    done
    echo "-1"
    return 1
}

# Joins elements in an array with a separator
# Takes a separator and an array of elements to join (as arguments)
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

# Gets input from the console
# Takes a string message and optionally a string default (not shown if secure is set) and a boolean secure flag for passwords
#
# Example
#   $ get-input "Enter a password" "123456" true
#   Enter a password (defaults to 1234) (not visible):
#   $ password=${RETVAL}
#
function get-input() {
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

function basename-git() {
    echo $(basename "$1" | tr '-' ' ' | sed 's/.sh$//g')
}

function timer-start() {
    NOW=$(date '+%s')
}

function timer-stop() {
    echo $(($(date '+%s')-${NOW})) >&2
}

########################################
# Bash functions
########################################

function ifs-off() {
    OLDIFS="${IFS}"
    IFS=
}

function ifs-on() {
    IFS="${OLDIFS}"
}

########################################
# Var functions
########################################

function var-type() {
    local var="${1}"
    if   [ -z "${var//[0-9]/}" ]
    then
        RETVAL="int"
    else
        RETVAL="string"
    fi
}

########################################
# Math functions
########################################

function math-rand() {
    local max=${1:-32767}
    local min=${2:-0}
    local tmp=
    # Swap min/max if wrong order
    if [ ${min} -gt ${max} ]
    then
        tmp=${min}
        min=${max}
        max=${tmp}
    fi
    range=$((max-min))
    # Reseed the RNG
    RANDOM=$$
    RETVAL=$(((RANDOM%range)+min))
}

function math-range() {
    local start=${1}
    local end=${2}
    if [ -z "${2}" ]
    then
        RETVAL=(${1})
        return
    fi
    # Swap min/max if wrong order
    if [ ${start} -gt ${end} ]
    then
        tmp=${start}
        start=${end}
        end=${tmp}
    fi
    # If only :(
    #RETVAL=({${start}..${stop}})
    RETVAL=()
    for (( c=${start}; c<=${end}; c++ ))
    do
        RETVAL+=($c)
    done
}

########################################
# String function
########################################

function string-unquote() {
    RETVAL="$1"
    RETVAL="${RETVAL%\'}"
    RETVAL="${RETVAL%\"}"
    RETVAL="${RETVAL#\'}"
    RETVAL="${RETVAL#\"}"
}

function string-escape() {
    RETVAL="${1}"
    RETVAL="${RETVAL/\(/\\(}"
    RETVAL="${RETVAL/\+/\\+}"
}

function string-to-array() {
    local string="${1}"
    RETVAL=()
    while IFS= read -r line
    do
        RETVAL+=("${line}")
    done <<< "${string}"
}

function string-exists() {
    local string="$1"
    local search="$2"
    string-replace "${string}" "${search}" "" true
    if [ "${string}" != "${RETVAL}" ]
    then
        RETVAL=true
        return 0
    else
        RETVAL=false
        return 1
    fi
}

function string-replace() {
    local string="$1"
    local search="$2"
    local replace="$3"
    local all=${4:-false}
    if ${all}
    then
        RETVAL="${string//${search}/${replace}}"
    else
        RETVAL="${string/${search}/${replace}}"
    fi
}

function string-match() {
    local string="$1"
    local search="$2"
    local all=${3:-false}
    local matches=()
    local surrounding=
    local removed=
    local len_r1=
    local len_r2=
    local len_s=
    local len=
    while :
    do
        string-replace "${string}" "${search}" $'\n'
        surrounding="${RETVAL}"
        if [ "${string}" == "${surrounding}" ]
        then
            break
        fi
        removed=()
        string-to-array "${surrounding}"
        removed=("${RETVAL[@]}")
        len_r1=${#removed[0]}
        len_r2=${#removed[1]}
        len_s=${#string}
        len=$((len_s-(len_r1+len_r2)))
        matches+=("${string:${len_r1}:${len}}")
        string="${removed[0]}${removed[1]}"
        if ! ${all}
        then
            break
        fi
    done
    RETVAL=("${matches[@]}")
    if [ ${#matches[@]} -gt 0 ]
    then
        return 0
    else
        return 1
    fi
}

function string-split() {
    local string="$1"
    local search="$2"
    local all=${3:-false}
    local matches=()
    local surrounding=
    local removed=
    local len_r1=
    local len_r2=
    local len_s=
    local len=
    while :
    do
        string-replace "${string}" "${search}" $'\n'
        surrounding="${RETVAL}"
        if [ "${string}" == "${surrounding}" ]
        then
            matches+=("${string}")
            break
        fi
        removed=()
        string-to-array "${surrounding}"
        removed=("${RETVAL[@]}")
        len_r1=${#removed[0]}
        len_r2=${#removed[1]}
        len_s=${#string}
        len=$((len_s-(len_r1+len_r2)))
        matches+=("${removed[0]}")
        matches+=("${string:${len_r1}:${len}}")
        string="${removed[1]}"
        if ! ${all}
        then
            matches+=("${string}")
            break
        fi
    done
    RETVAL=("${matches[@]}")
    if [ ${#matches[@]} -gt 1 ]
    then
        return 0
    else
        return 1
    fi
}

function string-compact() {
    string-replace "${1}" $'\n'$'\n' $'\n' true

}

function string-first() {
    local string="${1}"
    RETVAL="${string%%$'\n'*}"
}

function string-last() {
    local string="${1}"
    RETVAL="${string##*$'\n'}"
}

function string-trim-trailing-newline() {
    string="${1}"
    RETVAL="${string%$'\n'}"
}

########################################
# Array functions
########################################

function array-exists() {
    local search="${1}"
    local ARG2=("${!2}")
    local string="${ARG2[@]}"
    #echo string-exists " ${string} " " ${search} "
    string-exists " ${string} " " ${search} "
    # $?
}

function array-search() {
    local needle="$1"
    local ARG2=("${!2}")
    local array=("${ARG2}")
    for i in ${#array[@]}
    do
        if [ "${array[${i}]}" = "${needle}" ]
        then
            RETVAL="${i}"
            return 0
        fi
    done
    RETVAL="-1"
    return 1
}

function array-join() {
    local separator="${1}"
    local ARG2=("${!2}")
    local array=("${ARG2}")
    local head="${array[0]}"
    # Unfortunately MinGW doesn't slice arrays properly so we can't use tail=("${arr[@]:1}")
    unset array[0]
    tail=("${array[@]}")
    # No built-in seperator
    IFS= RETVAL="${head}${tail[@]/#/${separator}}"
}

function array-to-string() {
    local ARG1=("${!1}")
    array-join $'\n' "ARG1[@]"
    # RETVAL
}

function array-compare-int() {
    local pivot="${1}"
    local empty_front=${2:-false}
    local ARG3=("${!3}")
    local ARG4=("${!4}")
    local arr_key=("${ARG3[@]}")
    local arr_val=("${ARG4[@]}")
    RETKEY_F=()
    RETVAL_F=()
    RETKEY_L=()
    RETVAL_L=()
    RETKEY_E=()
    RETVAL_E=()
    RETKEY_G=()
    RETVAL_G=()
    RETKEY_B=()
    RETVAL_B=()
    for i in "${!arr_val[@]}"
    do
        if [ -z "${arr_val[${i}]}" ]
        then
            if ${empty_front}
            then
                RETKEY_F+=("${arr_key[${i}]}")
                RETKEY_F+=("${arr_val[${i}]}")
            else
                RETKEY_B+=("${arr_key[${i}]}")
                RETKEY_B+=("${arr_val[${i}]}")
            fi
        elif [ ${arr_val[${i}]} -lt ${pivot} ]
        then
            RETKEY_L+=("${arr_key[${i}]}")
            RETVAL_L+=("${arr_val[${i}]}")
        elif [ ${arr_val[${i}]} -gt ${pivot} ]
        then
            RETKEY_G+=("${arr_key[${i}]}")
            RETVAL_G+=("${arr_val[${i}]}")
        else
            RETKEY_E+=("${arr_key[${i}]}")
            RETVAL_E+=("${arr_val[${i}]}")
        fi
    done
}

function array-compare-string() {
    local pivot="${1}"
    local empty_front=${2:-false}
    local ARG2=("${!3}")
    local ARG3=("${!4}")
    local arr_key=("${ARG2[@]}")
    local arr_val=("${ARG3[@]}")
    RETKEY_F=()
    RETVAL_F=()
    RETKEY_L=()
    RETVAL_L=()
    RETKEY_E=()
    RETVAL_E=()
    RETKEY_G=()
    RETVAL_G=()
    RETKEY_B=()
    RETVAL_B=()
    for i in "${!arr_val[@]}"
    do
        if [ -z "${arr_val[${i}]}" ]
        then
            if ${empty_front}
            then
                RETKEY_F+=("${arr_key[${i}]}")
                RETKEY_F+=("${arr_val[${i}]}")
            else
                RETKEY_B+=("${arr_key[${i}]}")
                RETKEY_B+=("${arr_val[${i}]}")
            fi
        elif [ "${arr_val[${i}]}" \< "${pivot}" ]
        then
            RETKEY_L+=("${arr_key[${i}]}")
            RETVAL_L+=("${arr_val[${i}]}")
        elif [ "${arr_val[${i}]}" \> "${pivot}" ]
        then
            RETKEY_G+=("${arr_key[${i}]}")
            RETVAL_G+=("${arr_val[${i}]}")
        else
            RETKEY_E+=("${arr_key[${i}]}")
            RETVAL_E+=("${arr_val[${i}]}")
        fi
    done
}

function array-quicksort() {
    local ARG1=("${!1}")
    local ARG3=("${!3}")
    local i=
    local arr_len=${#ARG1[@]}
    local arr_val=("${ARG1[@]}")
    local arr_key=(${ARG3[@]})
    if [ "${#arr_key[@]}" -eq 0 ]
    then
        for ((i=0; i<arr_len; i++))
        do
            arr_key+=("${i}")
        done
    fi
    local compare_func="${2:-array-compare-int}"
    local arr_key_f=()
    local arr_val_f=()
    local arr_key_l=()
    local arr_val_l=()
    local arr_key_e=()
    local arr_val_e=()
    local arr_val_g=()
    local arr_key_g=()
    local arr_key_b=()
    local arr_val_b=()
    local pivot=
    if [ ${arr_len} -le 1 ]
    then
        RETKEY=("${arr_key[@]}")
        RETVAL=("${arr_val[@]}")
    else
        math-rand ${arr_len}
        pivot="${arr_val[${RETVAL}]}"
        ${compare_func} "${pivot}" false "arr_key[@]" "arr_val[@]"
        arr_key_f=("${RETKEY_F[@]}")
        arr_val_f=("${RETVAL_F[@]}")
        arr_key_l=("${RETKEY_L[@]}")
        arr_val_l=("${RETVAL_L[@]}")
        arr_key_e=("${RETKEY_E[@]}")
        arr_val_e=("${RETVAL_E[@]}")
        arr_key_g=("${RETKEY_G[@]}")
        arr_val_g=("${RETVAL_G[@]}")
        arr_key_b=("${RETKEY_B[@]}")
        arr_val_b=("${RETVAL_B[@]}")
        array-quicksort "arr_val_l[@]" "${compare_func}" "arr_key_l[@]"
        arr_key_l=("${RETKEY[@]}")
        arr_val_l=("${RETVAL[@]}")
        array-quicksort "arr_val_g[@]" "${compare_func}" "arr_key_g[@]"
        arr_key_g=("${RETKEY[@]}")
        arr_val_g=("${RETVAL[@]}")
        RETKEY=("${arr_key_f[@]}" "${arr_key_l[@]}" "${arr_key_e[@]}" "${arr_key_g[@]}" "${arr_key_b[@]}")
        RETVAL=("${arr_key_f[@]}" "${arr_key_l[@]}" "${arr_val_e[@]}" "${arr_val_g[@]}" "${arr_val_b[@]}")
    fi
}

########################################
# Matrix functions
########################################

function matrix-count-rows() {
    local matrix="${1}"
    local all=(${matrix//$'\n'/ })
    local len=${#all[@]}
    matrix-count-cols "${matrix}"
    RETVAL=$((len/RETVAL))
}

function matrix-count-cols() {
    string-first "${1}"
    local first=(${RETVAL})
    RETVAL=${#first[@]}
}

function matrix-get-rows() {
    local matrix="${1}"
    var-type "${2}"
    if [ "${RETVAL}" == "string" ]
    then
        local ARG2=("${!2}")
        local rows=("${ARG2[@]}")
    else
        math-range ${2} ${3}
        local rows=("${RETVAL[@]}")
    fi
    local output=
    local l=${#rows[@]}
    local i=0
    local c=0
    local var=
    while IFS=" " read -r line
    do
        if [ -z "${line}" ]
        then
            continue
        fi
        if array-exists "$i" "rows[@]"
        then
            # Fake array with variable indirection
            declare "line_${i}"="${line}"
            : $((c++))

        fi
        # If we have matched all the rows then break
        if [ ${c} -ge ${l} ]
        then
            break
        fi
        : $((i++))
    done <<< "${matrix}"
    matrix=
    for i in ${!rows[@]}
    do
        var="line_${rows[$i]}"
        matrix+="${!var}"$'\n'
    done
    string-trim-trailing-newline "${matrix}"
}

function matrix-get-cols() {
    local matrix="${1}"
    var-type "${2}"
    if [ "${RETVAL}" == "string" ]
    then
        local ARG2=("${!2}")
        local cols=("${ARG2[@]}")
    else
        math-range ${2} ${3}
        local cols=("${RETVAL[@]}")
    fi
    local array=
    local output=
    while IFS=" " read -r -a line
    do
        if [ -n "${line}" ]
        then
            array=()
            for i in "${cols[@]}"
            do
                array+=(${line[${i}]})
            done
            output+="${array[@]}"$'\n'
        fi
    done <<< "${matrix}"
    RETVAL="${output}"
}

function matrix-get() {
    local matrix="${1}"
    local row="${2:-0}"
    local col="${3:-0}"
    components-get-row "${matrix}" ${row}
    RETVAL=${RETVAL[${col}]}
}

function matrix-set() {
    local matrix="${1}"
    local row="${2}"
    local col="${3}"
    local value="${4}"
    local i=0
    while IFS=" " read -r -a line
    do
        if [ ${i} -eq ${row} ];
        then
            line[${col}]='"'${value}'"'
        fi
        RETVAL+="${line[@]}"$'\n'
        : $((i++))
    done <<< "${matrix}"
}

function matrix-split-rows() {
    local matrix="${1}"
    local col="${2}"
    local i=0
    local var=
    local prev=
    local splits=()
    while IFS=" " read -r -a line
    do
        if [ "${line[${col}]}" != "${prev}" ]
        then
            splits+=(${i})
            prev="${line[${col}]}"
        fi
        : $((i++))
    done <<< "${matrix}"
    matrix-count-rows "${matrix}"
    # Add the end if not already added
    if [ ${splits[@]: -1} -lt ${RETVAL} ]
    then
        splits+=(${RETVAL})
    fi
    RETVAL=(${splits[@]})
}

function matrix-to-array() {
    local matrix="${1}"
    array=()
    while IFS= read -r -a line
    do
        if [ -n "${line[@]}" ]
        then
            for i in ${line[@]}
            do
                string-unquote "${i}"
                array+=("${RETVAL}")
            done
        fi
    done <<< "${matrix}"
    RETVAL=("${array[@]}")
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
        (cd "${dir}" && git fetch && git fetch --tags) > /dev/null 2>&1
        local version=$(cd "${dir}" && git tag | grep "^[0-9]\+\.[0-9]\+\.[0-9]\+$" | sort -t. -k 1,1n -k 2,2n -k 3,3n | tail -1)
        if update-force-enabled || [ $(cd "${dir}" && git rev-list --left-right HEAD...${version} | grep "^>" | wc -l | sed 's/ //g') -gt 0 ]
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

    get-input "New version ${version} found. Update (y/n)?" "y"
    do_update="$(echo ${RETVAL} | tr '[:upper:]' '[:lower:]')"
    if [ "${do_update}" == "y" ] || [ "${do_update}" == "yes" ]
    then
        if [ -n "$silent" ]
        then
            echo -e "Updating. Rerun your command with this new version:\n\n$(basename-git $0) ${ARGS}"
        fi
        # Disown this subshell to allow this script to close and avoid permission denied errors due to file locking
        ( sleep 1 && cd ${dir} && git checkout ${version} > /dev/null 2>&1 && ./install.sh ) &
        disown
        exit
    fi
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
    for (( i=0; i <= $(( $total-1 )); i++ ))
    do
        plugin_type=${types[${i}]}
        plugin_dir="${dirs[${i}]}/.git-semver/plugins"
        if [ -d "${plugin_dir}" ]
        then
            find "${plugin_dir}" -maxdepth 1 -type f \( -perm -u=x -o -perm -g=x -o -perm -o=x \) -exec bash -c "[ -x {} ]" \; -printf "${plugin_type},%p \n"
        fi
    done
}

plugin-run() {
    local plugins="$(plugin-list)"
    local version_new="$1"
    local version_current="$2"
    local status=0
    local type=
    local type_lower=
    local path=
    local file=
    local name=
    for i in ${plugins}
    do
        type=${i%%,*}
        type_lower=$(echo ${type} | tr '[:upper:]' '[:lower:]')
        path=${i##*,}
        name=$(basename ${path})
        #name=${file%.*}
        ${path} "${version_new}" "${version_current}" "${GIT_HASH}" "${GIT_BRANCH}" "${DIR_ROOT}" | plugin-output "${type}" "${name}"
        RETVAL=${PIPESTATUS[0]}
        case ${RETVAL} in
            0)
                ;;
            111|1)
                echo -e "\nError: Warning from ${type_lower} plugin \"${name}\", ignoring"
                ;;
            112)
                echo -e "\nError: Error from ${type_lower} plugin \"${name}\", unable to version"
                status=1
                ;;
            113)
                echo -e "\nError: Fatal error from ${type_lower} plugin \"${name}\", unable to version, quitting immediately"
                return 1
                ;;
            *)
                echo -e "\nError: Unknown error from ${type_lower} plugin \"${name}\", ignoring"
        esac
    done
    return ${status}
}

########################################
#
########################################

function version-format-to-tokens() {
    RETVAL="${1}"
    string-replace "${RETVAL}" "{"         $'\n'$'{'$'\n' true
    string-replace "${RETVAL}" "}"         $'\n'$'}'$'\n' true
}

function version-matrix-to-string() {
    local tokens="${1}"

    string-unquote "${2}"
    local major="${RETVAL}"
    string-unquote "${3}"
    local minor="${RETVAL}"
    string-unquote "${4}"
    local patch="${RETVAL}"
    string-unquote "${5}"
    local prerel="${RETVAL}"
    string-unquote "${6}"
    local build="${RETVAL}"

    local version=
    local counter=0
    local direction=0
    local prefix=
    local suffix=
    local var=

    while IFS= read -r token
    do
        case "${token}" in
            "{")
                : $((counter++))
                direction=1
                ;;
            "}")
                : $((counter--))
                direction=-1
                ;;
            *)
                if [ ${counter} -eq 0 ]
                then
                    direction=0
                fi
        esac
        case "${token}" in
            "")
                if [ ${counter} -eq 0 ]
                then
                    prefix=
                    suffix=
                fi
                ;;
            "major"|"minor"|"patch"|"prerel"|"build")
                var=${!token}
                ;;
            "{")
                ;;
            "}")
                if [ ${counter} -eq 0 ] && [ -n "${var}" ]
                then
                    version+="${prefix}${var}${suffix}"
                fi
                ;;
            *)
                case ${counter} in
                    # Non var
                    0)
                        version+="${token}"
                        ;;
                    # Prefix or suffix
                    1)
                        if [ ${direction} -eq  1 ]
                        then
                            prefix="${token}"
                        fi
                        if [ ${direction} -eq -1 ]
                        then
                            suffix="${token}"
                        fi
                        ;;
                    # Unknown var
                    2)
                        var=
                        match=
                        ;;
                esac
        esac
        #printf "%-7s : %s : %2s : %s \n" "${token}" "${counter}" "${direction}" "${version}"
    done <<< "${tokens}"
    RETVAL="${version}"
}

function version-string-to-matrix() {
    local tokens="${1}"
    local version="${2}"

    local counter=0
    local direction=0
    local prefix=
    local suffix=
    local var=
    local match=

    while IFS= read -r token
    do
        string-escape "${token}"
        token="${RETVAL}"
        case "${token}" in
            "{")
                : $((counter++))
                direction=1
                ;;
            "}")
                : $((counter--))
                direction=-1
                ;;
            *)
                if [ ${counter} -eq 0 ]
                then
                    direction=0
                fi
        esac
        case "${token}" in
            "")
                if [ ${counter} -eq 0 ]
                then
                    prefix=
                    suffix=
                fi
                ;;
            "major"|"minor"|"patch")
                var="${token}"
                match="+([0-9])"
                ;;
            "prerel"|"build")
                var="${token}"
                match="+([0-9A-Za-z.])"
                ;;
            "{")
                ;;
            "}")
                if [ ${counter} -eq 0 ] && [ -n "${var}" ]
                then
                    string-split "${version}" "${prefix}${match}${suffix}"
                    if [ ${#RETVAL[@]} -gt 1 ]
                    then
                        version="${RETVAL[2]}"
                        # Remove prefix and suffix
                        string-split "${RETVAL[1]}" "${match}"
                        declare "${var}"="${RETVAL[1]}"
                    fi
                fi
                ;;
            *)

                case ${counter} in
                    # Non var
                    0)
                        string-replace "${version}" "${token}"
                        version="${RETVAL}"
                        ;;
                    # Prefix or suffix
                    1)
                        if [ ${direction} -eq  1 ]
                        then
                            prefix="${token}"
                        fi
                        if [ ${direction} -eq -1 ]
                        then
                            suffix="${token}"
                        fi
                        ;;
                    # Unknown var
                    2)
                        var=
                        match=
                        ;;
                esac
        esac
        #printf "%-7s : %s : %2s : %s \n" "${token}" "${counter}" "${direction}" "${version}"
    done <<< "${tokens}"
    RETVAL="\"${major}\" \"${minor}\" \"${patch}\" \"${prerel}\" \"${build}\""
}

function version-latest() {
    local versions="${1}"
    local matrix=
    # Parse versions
    while IFS= read -r line
    do
        if [ -n "${line}" ]
        then
            version-string-to-matrix "${VERSION_TOKENS}" "${line}"
            matrix+="${RETVAL}"$'\n'
        fi
    done <<< "$versions"
    string-trim-trailing-newline "${matrix}"
    version-sort "${RETVAL}" 0 "array-compare-int" 1 "array-compare-int" 2 "array-compare-int" 3 "array-compare-string"
    string-last "${RETVAL}"
    version-matrix-to-string "${VERSION_TOKENS}" ${RETVAL}
}

function version-sort() {
    local matrix="${1}"
    local component=${2}
    local compare="${3}"
    shift
    shift
    shift
    if [ -z "${component}" ] || [ -z "${compare}" ]
    then
        RETVAL="${matrix}"
        return
    fi
    local i=
    local start=
    local end=
    local splits=()
    local splits_len=
    matrix-get-cols "${matrix}" ${component}
    matrix-to-array "${RETVAL}"
    col=("${RETVAL[@]}")
    array-quicksort "col[@]" "${compare}"
    order=("${RETKEY[@]}")
    matrix-get-rows "${matrix}" "order[@]"
    matrix="${RETVAL}"
    matrix-split-rows "${matrix}" ${component}
    splits=(${RETVAL[@]})
    splits_len=${#splits[@]}
    local matrix_sorted=
    for (( i=1; i<${splits_len}; i++ ))
    do
        start=${splits[$((i-1))]}
        end=${splits[${i}]}
        : $((end--))
        matrix-get-rows "${matrix}" ${start} ${end}
        version-sort "${RETVAL}" ${@}
        string-trim-trailing-newline "${RETVAL}"
        matrix_sorted+="${RETVAL}"$'\n'
    done
    string-trim-trailing-newline "${matrix_sorted}"
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

# Gets the newest version from an unsorted list of strings
# Takes an unsorted list of strings and a string version format
#
#
version-latestx() {
    local format="${VERSION_FORMAT}"
    local strings="$(echo "${DEBUG_STRINGS}" | grep '[0-9]')"
    local limit=5

    # Parse versions
    local versions=
    for i in ${strings}
    do
        versions+="$(version-parse-2 "${i}" "${format}")"$'\n'
    done
    versions=$(strip-empty-lines "${versions}")

    echo "${versions}"
    echo "==="

    #version-rotate "${versions}"
    return

    for i in {0..4}
    do
        # If we only have one candidate then only rotate
        if [ $(echo "${versions}" | wc -l) -eq 1 ]
        then
            versions=$(version-rotate "${versions}")
        fi

        if [ ${i} -lt 3 ]
        then
            versions=$(version-reduce-num "${versions}" "max" "-n")
        elif [ ${i} -eq 3 ]
        then
            versions=$(version-reduce-prerel "${versions}" "max" "-n")
        fi

        versions=$(version-rotate "${versions}")

    done

    echo "${versions}" | head -n 1

:<<'COMMENT'
COMMENT

}

version-rotate() {
    local versions="$1"
    local rotations=1 ; [ -n "$2" ] && rotations="$2"

    OLDIFS="${IFS}"
    IFS=$'\n'
    for i in ${versions}
    do
        IFS=" "
        version=(${i})
        for i in ${!version[@]}
        do
            echo -n "${i} "
        done
        echo
    done
    IFS="${OLDIFS}"

    #echo "${1}" | sed 's#^\([^ ]\+\) \(.*\)$#\2 \1#g'
}

version-reduce-num() {
    local lines="$1"
    local func="$2"
    if [ "${func}" == "max" ]
    then
        command='tail'
    else
        command='head'
    fi
    local sorted=$(echo "${lines}" | sort -n)
    local match=$(echo "${sorted}" | ${command} -n 1 | sed 's#^\([^ ]\+\).*$#\1#g')
    echo "${lines}" | grep '^'${match}
}

version-reduce-prerel() {
    local lines="$1"
    local func="$2"
    local nonempty=
    local command='head'

    # Separate empty
    local empty=$(echo "lines" | grep '^"" ')

    # If we want the max and there are empty prereleases
    if [ "${func}" == "max" ] && [ -n "${empty}" ]
    then
        echo "${empty}"
        return 0
    fi

    # If there are empty get the nonempty
    if [ -n "${empty}" ]
    then
        nonempty=$(echo "lines" | grep -v '^"" ')
    else
        nonempty="${lines}"
    fi

    if [ "${func}" == "max" ]
    then
        command='tail'
    fi

    # Sort the non-empty
    local sorted=$(echo "${nonempty}" | sed 's#^"\([^"]\+\)" \(.*\)#\1 \2#g' | sort -n)
    #local match=$(echo "${sorted}" | ${command} -n 1 | sed 's#^\([^ ]\+\).*$#\1#g')
    #echo "${lines}" | grep '^"'${match}'"'

}

strip-empty-lines() {
    echo "${1}" | grep -v '^$'
}

version-parse-2() {
    local version="$1"
    local format="$2"

    # If version doesn't match format then error
    if echo "${version}" | grep -v -q "${VERSION_MATCHES[0]}"
    then
        return 1
    fi

    # Parse components out version
    #components=()
    for i in "${!VERSION_MATCHES[@]}"
    do
        echo -n "${version}" | sed 's#'${VERSION_MATCHES[${i}]}'#'${VERSION_COMPONENTS_NAMES[${i}]}' \'${VERSION_CAPTURES[${i}]}'\n#g'
        #components+=($(echo -n "${version}" | sed 's#'${VERSION_MATCHES[${i}]}'#'${VERSION_COMPONENTS_NAMES[${i}]}' \'${VERSION_CAPTURES[${i}]}'#g'))
    done
    #echo "${components[@]}"
}

version-major() {
    local version=$(version-get)
    local major=
    local minor=
    local patch=
    local new=
    if [ "" == "${version}" ]
    then
        major=1
        minor=0
        patch=0
    else
        major=$(($(version-parse-major ${version})+1))
        minor=$(version-parse-minor ${version})
        patch=$(version-parse-patch ${version})
    fi
    new=$(version-format "${VERSION_FORMAT}" "${major}" "${minor}" "${patch}")
    version-do "${new}" "${version}"
}

version-minor() {
    local version=$(version-get)
    local major=
    local minor=
    local patch=
    local new=
    if [ "" == "${version}" ]
    then
        major=0
        minor=1
        patch=0
    else
        major=$(version-parse-major ${version})
        minor=$(($(version-parse-minor ${version})+1))
        patch=$(version-parse-patch ${version})
    fi
    new=$(version-format "${VERSION_FORMAT}" "${major}" "${minor}" "${patch}")
    version-do "${new}" "${version}"
}

version-patch() {
    local version=$(version-get)
    local major=
    local minor=
    local patch=
    local new=
    if [ "" == "${version}" ]
    then
        major=0
        minor=1
        patch=0
    else
        major=$(version-parse-major ${version})
        minor=$(version-parse-minor ${version})
        patch=$(($(version-parse-patch ${version})+1))
    fi
    new=$(version-format "${VERSION_FORMAT}" "${major}" "${minor}" "${patch}")
    version-do "${new}" "${version}"
}

version-do() {
    local new="$1"
    local version="$2"
    if plugin-run "$new" "$version"
    then
        git tag "$new" && echo "$new"
    fi
}

version-split() {
    echo "$1" | sed 's/\({[^}]*\)/\n\1/g ; s/\(}[^}]*}\)/\1\n/g' | sed '/^$/d'
}

version-replace() {
    local version="$1"
    local i=
    local index=-1
    # Avoid associative arrays as OSX doesn't support Bash 4
    local names=(  "major" "minor" "patch" "prerel" "build" "version"                                            )
    local values=( "$2"    "$3"    "$4"    "$5"     "$6"    "{{major}}.{{minor}}.{{patch}}{-{prerel}}{+{build}}" )
    OLDIFS="${IFS}"
    IFS=$'\n'
    for i in ${version}
    do
        name=$(echo "${i}" | grep '^{.*}$' | sed 's/.*{\([^}]*\)}.*/\1/g')
        # Not a variable so output it
        if [ "$name" == "" ]
        then
            echo ${i}
            continue
        fi
        index=$(index "${name}" "${names[@]}")
        # Not a valid variable so ignore it
        if [ ${index} -eq -1 ]
        then
            continue
        fi
        value=${values[${index}]}
        # No value for variable so ignore it
        if [ "${value}" == "" ]
        then
            continue
        fi
        # Output variable value
        echo "${i}" | sed 's/{'${name}'}/'${value}'/g ; s/^{//g ; s/}$//g'

    done
    IFS="${OLDIFS}"
}

version-join() {
    OLDIFS="${IFS}"
    IFS=$'\n'
    printf "%s" $1
    IFS="${OLDIFS}"
}

version-tokens-replace() {
    local ARGS2=("${!2}")
    local ARGS3=("${!3}")
    local ARGS4=("${!4}")

    local tokens="$1"
    local names=("${ARGS2[@]}")
    local values=("${ARGS3[@]}")
    local excludes=(); [ -n "$4" ] && excludes=("${ARGS4[@]}")

    local token=
    local name=
    local value=
    local index=

    OLDIFS="${IFS}"
    IFS=$'\n'
    for token in ${tokens}
    do
        name=$(echo "${token}" | grep '^{.*}$' | sed 's/.*{\([^}]*\)}.*/\1/g')
        # Not a variable so output it
        if [ "${name}" == "" ]
        then
            echo "${token}"
            continue
        fi
        index=$(index "${name}" "${excludes[@]}")
        # Excluded variable so output it
        if [ ${index} -ne -1 ]
        then
            echo "${token}"
            continue
        fi
        index=$(index "${name}" "${names[@]}")
        # Not a valid variable so ignore it
        if [ ${index} -eq -1 ]
        then
            continue
        fi
        value=${values[${index}]}
        # No value for variable so ignore it
        if [ "${value}" == "" ]
        then
            continue
        fi
        # Output variable value
        echo "${token}" | sed 's/{'${name}'}/'${value}'/g ; s/^{//g ; s/}$//g'
    done
    IFS="${OLDIFS}"
}


version-format-resolve() {
    local ARGS2=("${!2}")
    local ARGS3=("${!3}")
    local ARGS4=("${!4}")

    local format="$1"
    local names=("${ARGS2[@]}")
    local values=("${ARGS3[@]}")
    local excludes=(); [ -n "$4" ] && excludes=("${ARGS4[@]}")

    local components=$(join "\|" "${excludes[@]}")
    local limit=5


    # If no variables in version treat as a prefix
    if echo "${format}" | grep -v -q '{[^{]*{[^}]\+}[^}]*}'
    then
        format="${format}${VERSION_FORMAT_DEFAULT}"
    fi

    # Otherwise resolve
    while [ ${limit} -gt 0 ] && echo "${format}" | sed 's#{{\('${components}'\)}}##g' | grep -q '{{[^}]\+}}'
    do
        format="$(version-split          "${format}")"
        format="$(version-tokens-replace "${format}" "names[@]" "values[@]" "excludes[@]" )"
        format="$(version-join           "${format}")"
        : $((limit--))
    done
    echo "${format}"
}

version-format-replace() {
    local version="$1"

    local limit=5
    # If no variables in version treat as a prefix
    if echo ${version} | grep -v -q '{[^{]*{[^}]\+}[^}]*}'
    then
        version="${version}${VERSION_FORMAT_DEFAULT}"
    fi
    # Replace vars
    while [ ${limit} -gt 0 ] && echo ${version} | grep -q '{[^{]*{[^}]\+}[^}]*}'
    do
        : $((limit--))
        version="$(version-split          "${version}")"
        version="$(version-tokens-replace "${version}" "${major}" "${minor}" "${patch}" "${prerel}" "${build}")"
        version="$(version-join           "${version}")"
    done
    echo "${version}"
}

version-matches() {
    local format="$1"

    local match_num="\1[0-9]\\\\+\3"
    local match_alnum="\\\\(\1[0-9A-za-z.-]\\\\+\3\\\\)\\\\?"
    local capture_num="\1\\\\([0-9]\\\\+\\\\)\3"
    local capture_alnum="\\\\(\1\\\\([0-9A-za-z.-]\\\\+\\\\)\3\\\\)\\\\?"

    local patterns=(
        "${capture_num}"   # major
        "${capture_num}"   # minor
        "${capture_num}"   # patch
        "${capture_alnum}" # prerel
        "${capture_alnum}" # build
    )

    # Build matches to parse out components
    matches=()
    for i in "${!VERSION_COMPONENTS_NAMES[@]}"
    do
        nums=$(  echo "major|minor|patch" | sed 's#'${i}'##g; s#^|\||$##g; s#||#|#g; s#|#\\|#g')
        alnums=$(echo "prerel|build"      | sed 's#'${i}'##g; s#^|\||$##g;           s#|#\\|#g')
        matches+=("^"$(echo "${format}"   | sed 's#{\([^{]*\){\('${VERSION_COMPONENTS_NAMES[${i}]}'\)}\([^}]*\)}#'${patterns[${i}]}'#g; s#{\([^{]*\){\('${nums}'\)}\([^}]*\)}#'${match_num}'#g; s#{\([^{]*\){\('${alnums}'\)}\([^}]*\)}#'${match_alnum}'#g; s#{[^{]*{[^}]\+}[^}]*}##g')"$")
    done
    echo "${matches[@]}"
}

version-captures() {
    local format="$1"
    local capture=

    format="$(version-split "${format}")"
    captures=()
    for i in "${!VERSION_COMPONENTS_NAMES[@]}"
    do
        capture=1
        name=${VERSION_COMPONENTS_NAMES[$i]}
        if [ "${name}" == "prerel" ] || [ "${name}" == "build" ]
        then
            capture=$((capture+1))
        fi
        prefix="$(echo "${format}" | sed '/.*'${name}'.*/{Q}')"
        prerels=$(echo "${prefix}" | grep '{prerel}' | wc -l)
        builds=$(echo "${prefix}" | grep '{build}' | wc -l)
        capture=$((capture+prerels+builds))
        captures+=(${capture})
    done
    echo "${captures[@]}"
}

########################################
# Run
########################################

#
# Readonly vars
#
readonly DIR_HOME="${HOME}"
readonly VERSION_COMPONENTS_NAMES=("major" "minor" "patch" "prerel" "build")
readonly VERSION_COMPONENTS_META_NAMES=(  "version"                                            )
readonly VERSION_COMPONENTS_META_VALUES=( "{{major}}.{{minor}}.{{patch}}{-{prerel}}{+{build}}" )
readonly VERSION_FORMAT_DEFAULT="${VERSION_COMPONENTS_META_VALUES[0]}"

#
# Default config
#
UPDATE_CHECK=1
UPDATE_CHECK_INTERVAL_DAYS=1
VERSION_FORMAT="${VERSION_FORMAT_DEFAULT}"

#
# DEBUG TO REMOVE
#
VERSION_FORMAT="v{{version}}{{x}}.{{major}}"
#VERSION_FORMAT="{{version}}"
VERSION_FORMAT="v-{{prerel}-}{{minor}}.{{patch}}.{{major}}{{invalid}}{+{build}}"
DEBUG_STRINGS="$(cat <<-'EOF'
v-beta.2-0.2.10+3423
v-beta.2-0.2.10+3444
v-1.beta.2-0.2.10+3423
v-2.beta.2-0.2.10+3423
v-10.beta.2-0.2.10+3423
v-10.1beta.2-0.2.10+3423
v-10.10beta.2-0.2.10+3423
v-0.2.10+3423
v-alpha-1.1.1+1293
v-beta-0.1.3+dddd
v-alpha.1-1.1.1+3593
v-alpha-0.2.10+3423
v-beta-1.3.1
v-beta-0.1.2
v-beta-0.2.10+3423
v-alpha-0.2.10+3423
v-1.1.2
v--1.3.2
EOF
)"

VERSION_FORMAT="${VERSION_FORMAT_DEFAULT}"
DEBUG_STRINGS="$(cat <<-'EOF'
3.2.1
3.2.1+3423
3.2.1-alpha.1
3.2.1-beta.2+3423
1.2.3-alpha
3.2.1-alpha
3.2.1-alpha.2
1.2.3
3.2.1-alpha.10
3.2.1-beta.1+3423
10.2.3
3.2.1-beta
10.2.4
10.1.5-beta+1234
3.2.1-beta.2+3444
EOF
)"

#
# User config
#
if [ -f "${DIR_HOME}/.git-semver/config" ]
then
    source "${DIR_HOME}/.git-semver/config"
fi

#
# General vars
#
DIR_ROOT="$(git rev-parse --show-toplevel 2> /dev/null)"
DIR_DATA=${DIR_HOME}/.git-semver

FILE_CONF="${DIR_DATA}/config"
FILE_UPDATE="${DIR_DATA}/update"

GIT_HASH="$(git rev-parse HEAD 2> /dev/null)"
GIT_BRANCH="$(git rev-parse --abbrev-ref HEAD 2> /dev/null)"

#
# Caching
#
VERSION_FORMAT=$(version-format-resolve "${VERSION_FORMAT}" "VERSION_COMPONENTS_META_NAMES[@]" "VERSION_COMPONENTS_META_VALUES[@]" "VERSION_COMPONENTS_NAMES[@]")

version-format-to-tokens "${VERSION_FORMAT}"
VERSION_TOKENS="${RETVAL}"

#VERSION_MATCHES=($(version-matches "${VERSION_FORMAT}"))
#for i in "${VERSION_MATCHES[@]}"; do echo "${i}"; done
#exit
#VERSION_CAPTURES=($(version-captures "${VERSION_FORMAT}"))
#version=("3" "2" "1" "alpha" "2032")
#VERSION_FORMAT=$(version-format-resolve "${VERSION_FORMAT}" "VERSION_COMPONENTS_NAMES[@]" "version[@]")
#echo "${VERSION_FORMAT}"
#exit



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
    debug)
        version-latest "${DEBUG_STRINGS}"
        echo "${RETVAL}"
        ;;
    format)
        shift
        version-format "$@"
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
