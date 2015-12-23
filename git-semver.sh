#!/bin/bash

readonly DEBUG_BENCHMARK_START=$(date '+%s')
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
# Takes a search string and an array of elements to search
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

function debug-benchmark() {
    # Noop if not debugging
    [ ! $DEBUG ] && return
    DEBUG_BENCHMARK=${DEBUG_BENCHMARK:-DEBUG_BENCHMARK_START}
    local secs=$(($(date '+%s')-${DEBUG_BENCHMARK}))
    local plural=
    if [ ${secs} -ne 1 ]
    then
        plural=s
    fi
    echo "Time: ${secs} second${plural}" >&2
    DEBUG_BENCHMARK=$(date '+%s')
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
    local empty_is_int=${2:-false}
    if ${empty_is_int} || [ -n "${var}" ] && [ -z "${var//[0-9]/}" ]
    then
        RETVAL="int"
    else
        RETVAL="string"
    fi
}

function var-is-int() {
    var-type "${1}"
    [ "$RETVAL" == "int" ]
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

function string-count-chars() {
    local str1="${1}"
    local char="${2}"
    string-replace "${str1}" "${char}" "" true
    local str2="${RETVAL}"
    local str1_len=${#str1}
    local str2_len=${#str2}
    RETVAL=$((str1_len-str2_len))
}

function string-count-lines() {
    local string="${1}"
    local lines=()
    while IFS= read -r line
    do
        lines+=(${line})
    done <<< "${string// /\ }"
    RETVAL=${#lines[@]}
}

function string-get-lines() {
    local string="${1}"
    var-type "${2}"
    if [ "${RETVAL}" == "string" ]
    then
        local ARG2=("${!2}")
        local rows=("${ARG2[@]}")
        local row=
        local lines=()
        local sed_args=()
        local max=
        local i=
        for i in "${!rows[@]}"
        do
            # Ignore empties
            if [ -z "${rows[${i}]}" ]
            then
                continue
            fi
            # Bump zero-index to line number
            row=$((rows[${i}]+1))
            max=$((row > max ? row : max))
            # If this row is less than the max or max is undefined
            if [ ${row} -lt ${max} ]
            then
                # Create args
                array-join 'p;' "lines[@]"
                # Save args into a chunk
                sed_args+=("${RETVAL}p;d;q")
                # Reset lines and max
                lines=()
                max=1
            fi
            lines+=("${row}")
        done
        array-join 'p;' "lines[@]"
        sed_args+=("${RETVAL}p;d;q")
        RETVAL=
        for i in "${!sed_args[@]}"
        do
           RETVAL+=$(sed -ne "${sed_args[${i}]}" <<< "${string}")$'\n'
        done
        string-trim-trailing-newline "${RETVAL}"
    else
        local start=${2}
        local end=${3}
        local num=1
        if [ -n "${end}" ]
        then
            num=$((end-start+1))
        fi
        # Bump zero-index to line number
        : $((start++))
        : $((end++))
        RETVAL=$(tail -n+${start} <<< "${string}" | head -n ${num})
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
    local string="${1}"
    RETVAL="${string%$'\n'}"
}

function string-repeat() {
    local string="${1}"
    local number=${2:-1}
    local separator="${3}"
    RETVAL=()
    local i=
    for (( i=0; i<${number}; i++ ))
    do
        if [ ${i} -ne 0 ]
        then
            RETVAL+="${separator}"
        fi
        RETVAL+="${string}"
    done
}

########################################
# Comparison functions
########################################

function compare-int() {
    if [ ${1} -lt ${2} ]
    then
        RETVAL=-1
    elif [ ${1} -gt ${2} ]
    then
        RETVAL=1
    else
        RETVAL=0
    fi
}

function compare-string() {
    if [ "${1}" \< "${2}" ]
    then
        RETVAL=-1
    elif [ "${1}" \> "${2}" ]
    then
        RETVAL=1
    else
        RETVAL=0
    fi
}

function compare-prerel() {
    local string_1="${1}"
    local string_2="${2}"
    string_1="${string_1//./$'\n'}"
    string_2="${string_2//./$'\n'}"
    string-count-lines "${string_1}"
    local string_1_len="${RETVAL}"
    string-count-lines "${string_2}"
    local string_2_len="${RETVAL}"
    local line_1=
    local line_2=
    local max_len=$((string_1_len > string_2_len ? string_1_len : string_2_len))
    local i=
    local compare_val=
    for (( i=0; i<max_len; i++))
    do
        string-get-lines "${string_1}" $i
        line_1="${RETVAL}"
        string-get-lines "${string_2}" $i
        line_2="${RETVAL}"
        if var-is-int "${line_1}" && var-is-int "${line_2}"
        then
            compare-int ${line_1} ${line_2}
            [ ${RETVAL} -ne 0 ] && return
        else
            compare-string "${line_1}" "${line_2}"
            [ ${RETVAL} -ne 0 ] && return
       fi
    done
    RETVAL=0
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
    local array=("${ARG2[@]}")
    for i in ${#array[@]}
    do
        if [ "${array[${i}]}" == "${needle}" ]
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
    local array=("${ARG2[@]}")
    local head="${array[0]}"
    local tail=("${array[@]:1}")
    # Set IFS to empty
    local ifs="${IFS}"
    IFS=
    # Add separator around and between elements
    RETVAL="${head}${tail[@]/#/${separator}}"
    # Remove space before separator
    RETVAL="${RETVAL// ${separator}/${separator}}"
    # Restore IFS
    IFS="${ifs}"
}

function array-to-string() {
    local ARG1=("${!1}")
    local array=("${ARG1[@]}")
    array-join $'\n' "array[@]"
    # RETVAL
}

function array-compare() {
    local compare="${1}"
    local pivot="${2}"
    local ARG3=("${!3}")
    local ARG4=("${!4}")
    local arr_key=("${ARG3[@]}")
    local arr_val=("${ARG4[@]}")
    local empty_front=${5:-false}
    local compare_val=
    local i=
    RETVAL=
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
        else
            ${compare} "${arr_val[${i}]}" "${pivot}"
            compare_val=${RETVAL}
            if   [ ${compare_val} -eq -1 ]
            then
                RETKEY_L+=("${arr_key[${i}]}")
                RETVAL_L+=("${arr_val[${i}]}")
            elif [ ${compare_val} -eq 1  ]
            then
                RETKEY_G+=("${arr_key[${i}]}")
                RETVAL_G+=("${arr_val[${i}]}")
            else
                RETKEY_E+=("${arr_key[${i}]}")
                RETVAL_E+=("${arr_val[${i}]}")
            fi
        fi
    done
}

function array-sort() {
    local ARG1=("${!1}")
    local ARG3=("${!3}")
    local i=
    local arr_len=${#ARG1[@]}
    local arr_val=("${ARG1[@]}")
    local arr_key=(${ARG3[@]})
    local arr_key_empty=()
    local arr_val_empty=()
    if [ ${arr_len} -eq 0 ]
    then
        RETKEY=()
        RETVAL=()
        return
    fi
    if [ "${#arr_key[@]}" -eq 0 ]
    then
        for ((i=0; i<arr_len; i++))
        do
            arr_key+=("${i}")
        done
    fi
    local sort_args="${2:--k2,2n}"
    local arr_combined=()
    for i in "${!arr_val[@]}"
    do
        arr_combined+=("${arr_key[${i}]}.${arr_val[${i}]}")
    done
    array-to-string "arr_combined[@]"
    arr_combined="$(sort -t. ${sort_args} -k1,1n  <<< "${RETVAL}")"
    string-to-array "${arr_combined}"
    arr_combined=("${RETVAL[@]}")
    arr_key=()
    arr_val=()
    for i in "${!arr_combined[@]}"
    do
        string-split "${arr_combined[${i}]}" "."
        if [ -n "${RETVAL[2]}" ]
        then
            arr_key+=("${RETVAL[0]}")
            arr_val+=("${RETVAL[2]}")
        else
            arr_key_empty+=("${RETVAL[0]}")
            arr_val_empty+=("${RETVAL[2]}")
        fi
    done
    RETKEY=("${arr_key[@]}" "${arr_key_empty[@]}")
    RETVAL=("${arr_val[@]}" "${arr_val_empty[@]}")
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
    local compare="${2:-compare-int}"
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
        array-compare "${compare}" "${pivot}" "arr_key[@]" "arr_val[@]"
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
        array-quicksort "arr_val_l[@]" "${compare}" "arr_key_l[@]"
        arr_key_l=("${RETKEY[@]}")
        arr_val_l=("${RETVAL[@]}")
        array-quicksort "arr_val_g[@]" "${compare}" "arr_key_g[@]"
        arr_key_g=("${RETKEY[@]}")
        arr_val_g=("${RETVAL[@]}")
        RETKEY=("${arr_key_f[@]}" "${arr_key_l[@]}" "${arr_key_e[@]}" "${arr_key_g[@]}" "${arr_key_b[@]}")
        RETVAL=("${arr_key_f[@]}" "${arr_key_l[@]}" "${arr_val_e[@]}" "${arr_val_g[@]}" "${arr_val_b[@]}")
    fi
}

array-type() {
    local ARG1=("${!1}")
    local array=("${ARG1[@]}")
    local empty_is_int=${2:-false}
    local i=
    for i in "${!array[@]}"
    do
        var-type "${array[${i}]}" ${empty_is_int}
        if [ "${RETVAL}" == "string" ]
        then
            return
        fi
    done
}

########################################
# Matrix functions
########################################

function matrix-count-rows() {
    local matrix="${1}"
    local all=(${matrix//$'\n'/ })
    local len=${#all[@]}
    matrix-count-cols "${matrix}"
    if [ ${RETVAL} -eq 0 ]
    then
        RETVAL=${len}
    else
        RETVAL=$((len/RETVAL))
    fi
}

function matrix-count-cols() {
    string-first "${1}"
    local first=(${RETVAL})
    RETVAL=${#first[@]}
}

function matrix-get-rows() {
    string-get-lines "$@"
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

# Splits a matrix into multiple rows (returning indexes of rows) when the data 
# is different
#
# Example
#   $ matrix-split-rows "$(echo -e "\"a\" \n\"a\" \n\"b\" \n\"b\" \n\"c\" \n\"c\" ")" 0
#   $ echo "${RETVAL[@]}"
#   (0 2 4)
#
function matrix-split-rows() {
    local matrix="${1}"
    local col="${2}"
    RETVAL=($(echo "${matrix}" | awk -v col="${col}" '
        BEGIN { 
            prev=""
            curr=""
            space=""
            last=0
            col=col+1
        } 
        { 
            prev=curr; 
            curr=$col; 
            if (curr != prev) { 
                last=NR-1
                printf "%s%s", space, last
                space=" "
            } 
        }
        END {
            if (NR != last) {
                printf " %s", NR
            }
        }
    '))
}

function matrix-to-array() {
    local matrix="${1}"
    local i=
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
# Sort functions
########################################

function sort-args-increment() {
    :
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

function version-strings-to-matrix() {
  local tokens="${1}"
  local versions="${2}"
  RETVAL=$(echo "${versions}" | awk -v tokens="${tokens}" '
    BEGIN {
        n=split(tokens, ts, "\n")
    }
    {
        line=$0
        counter=0
        direction=0
        prefix=""
        suffix=""
        var=""
        regexp=""
        for (i=0; i<n; i++) {
            t=ts[i]
            if (t == "{") {
                counter++
                direction=1
            } else if (t == "}") {
                counter--
                direction=-1
            } else {
                if (counter == 0) {
                    direction = 0
                }
            }
            if (t == "") {
                if (counter == 0) {
                    prefix=""
                    suffix=""
                }
            } else if (t == "major"|| t == "minor" || t == "patch") {
                var=t
                regexp="[0-9]+"
            } else if (t == "prerel" || t == "build") {
                var=t
                regexp="[0-9A-Za-z.]+"
            } else if (t == "{") {
            } else if (t == "}") {
                if (counter == 0 && var != "") {
                    match(line, prefix regexp suffix)
                    if (RLENGTH > -1) {
                        parsed[var]=substr(line, RSTART, RLENGTH)
                        line=substr(line, RSTART+RLENGTH, length(line))
                    }
                }
            } else {
                # Non var
                if (counter == 0) {
                    sub(token, "", $line)
                # Prefix or suffix
                } else if (counter == 1) {
                    if (direction == 1) {
                        prefix=token
                    } 
                    else if (direction == -1) {
                        suffix=token
                    }
                # Unknown var
                } else if (counter == 2) {
                    var=""
                    regexp=""
                }
            }
        }
        printf "\"%s\" \"%s\" \"%s\" \"%s\" \"%s\"\n", parsed["major"], parsed["minor"], parsed["patch"], parsed["prerel"], parsed["build"]
    }
  ')
}

function version-sort() {
    local matrix="${1}"
    local component=${2}
    local sort_args="${3}"
    shift
    shift
    shift
    if [ -z "${component}" ] || [ -z "${sort_args}" ]
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
    local col=("${RETVAL[@]}")
echo {{{
#debug-benchmark
echo "--- array-sort"
    array-sort "col[@]" "${sort_args}"
    #array-quicksort "col[@]" "${compare}"
    order=("${RETKEY[@]}")
debug-benchmark
echo "--- matrix-get-rows"
    matrix-get-rows "${matrix}" "order[@]"
    matrix="${RETVAL}"
#debug-benchmark
echo "--- matrix-split-rows"
#echo matrix-split-rows '${matrix}' ${component}
    matrix-split-rows "${matrix}" ${component}
    splits=(${RETVAL[@]})
    splits_len=${#splits[@]}
#echo "${splits[@]}"
#echo "${splits_len}"
debug-benchmark
echo }}}
    local matrix_sorted=
    for (( i=1; i<${splits_len}; i++ ))
    do
        start=${splits[$((i-1))]}
        end=${splits[${i}]}
        : $((end--))
        matrix-get-rows "${matrix}" ${start} ${end}
        if [ "${RETVAL}" != "" ]
        then
            version-sort "${RETVAL}" "${@}"
            matrix_sorted+="${RETVAL}"$'\n'
        fi
    done
    string-trim-trailing-newline "${matrix_sorted}"
}

function version-latest() {

    local versions="${1}"
    local matrix=
    # Parse versions
#echo '--- version-string-to-matrix'
#    while IFS= read -r line
#    do
#        if [ -n "${line}" ]
#        then
#            version-string-to-matrix "${VERSION_TOKENS}" "${line}"
#debug-benchmark
#            matrix+="${RETVAL}"$'\n'
#        fi
#    done <<< "${versions}"
#    string-trim-trailing-newline "${matrix}"
#    matrix="${RETVAL}"
#echo "${matrix}"
#debug-benchmark
#echo '--- version-strings-to-matrix'
    version-strings-to-matrix "${VERSION_TOKENS}" "${versions}"
    matrix="${RETVAL}"
#echo "${matrix}"
#debug-benchmark
#exit
echo '--- version-prerel-sort-args'
    matrix-get-cols "${matrix}" 3
    version-prerel-sort-args "${RETVAL}" 2
    sort_args="${RETVAL}"
debug-benchmark
echo '--- version-sort'
    version-sort "${matrix}" 0 "-k2,2n" 1 "-k2,2n" 2 "-k2,2n" 3 "${sort_args}"
debug-benchmark
    string-last "${RETVAL}"
    version-matrix-to-string "${VERSION_TOKENS}" ${RETVAL}
}

function version-prerels-to-matrix() {
    local prerels="${1}"
    local component=0
    while IFS= read -r line
    do
        string-count-chars "${line}" "."
        components=$((RETVAL > components ? RETVAL : components))
    done <<< "${prerels}"
    #: $((components++))
    local index=
    local matrix=""
    while IFS= read -r line
    do
        string-unquote "${line}"
        line="${RETVAL}"
        string-split "${line}" "." true
        for (( i = 0 ; i <= components; i++ ))
        do
            index=$((i*2))
            if [ $i -ne 0 ]
            then
                matrix+=" "
            fi
            matrix+="\"${RETVAL[${index}]}\""
        done
        matrix+=$'\n'
    done <<< "${prerels}"
    string-trim-trailing-newline "${matrix}"
}

function version-prerel-sort-args() {
    local string="${1}"
    local offset="${2:-1}"
    local matrix=
    local count=
    local i=
    local sort_args=
    local array=
    local field=
    version-prerels-to-matrix "${string}"
    matrix="${RETVAL}"
    matrix-count-cols "${matrix}"
    count=${RETVAL}
    for (( i=0 ; i<count ; i++ ))
    do
        field=$((i+offset))
        if [ ${i} -ne 0 ]
        then
            sort_args+=" "
        fi
        matrix-get-cols "${matrix}" ${i}
        matrix-to-array "${RETVAL}"
        array=("${RETVAL[@]}")
        array-type "array[@]" true
        sort_args+="-k${field},${field}"
        case "${RETVAL}" in
            int)
                sort_args+="n"
                ;;
            string)
                sort_args+="d"
                ;;
        esac
    done
    RETVAL="${sort_args}"
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
    for i in "${VERSION_COMPONENTS_NAMES[@]}"
    do
        :
        #nums=$(  echo "major|minor|patch" | sed 's#'${i}'##g; s#^|\||$##g; s#||#|#g; s#|#\\|#g')
        #alnums=$(echo "prerel|build"      | sed 's#'${i}'##g; s#^|\||$##g;           s#|#\\|#g')
        #matches+=("^"$(echo "${format}"   | sed 's#{\([^{]*\){\('${VERSION_COMPONENTS_NAMES[${i}]}'\)}\([^}]*\)}#'${patterns[${i}]}'#g; s#{\([^{]*\){\('${nums}'\)}\([^}]*\)}#'${match_num}'#g; s#{\([^{]*\){\('${alnums}'\)}\([^}]*\)}#'${match_alnum}'#g; s#{[^{]*{[^}]\+}[^}]*}##g')"$")
    done
    RETVAL=("${matches[@]}")
}

version-captures() {
    local format="$1"
    local capture=

    format="$(version-split "${format}")"
    captures=()
    for i in "${VERSION_COMPONENTS_NAMES[@]}"
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
    RETVAL=("${captures[@]}")
}

########################################
# Run
########################################

#
# Readonly vars
#
readonly DEBUG=true
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
10.2.1-alpha.10
3.2.1-beta.1+3423
3.4.1-alpha.10
3.2.1-beta.1+3423
3.3.1-alpha.10
EOF
)"
DEBUG_PRERELS=$(cat <<-'EOF'
alpha.2
beta
beta.2.2
beta.2.100.a4
gamma.3
beta.beta
gamma.1.1
alpha

alpha.1

beta.2
beta.20
beta.100
beta.1
EOF
)

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

#echo "---version-matches"
#version-matches "${VERSION_FORMAT}"
#VERSION_MATCHES=("${RETVAL[@]}")
#for i in "${VERSION_MATCHES[@]}"; do echo "${i}"; done

#echo "---version-captures"
#version-captures "${VERSION_FORMAT}"
#VERSION_CAPTURES=("${RETVAL[@]}")
#for i in "${VERSION_CAPTURES[@]}"; do echo "${i}"; done
#exit

#version=("3" "2" "1" "alpha" "2032")
#VERSION_FORMAT=$(version-format-resolve "${VERSION_FORMAT}" "VERSION_COMPONENTS_NAMES[@]" "version[@]")
#echo "${VERSION_FORMAT}"
#exit
#echo "${VERSION_TOKENS}"
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

        #version-prerel-sort-args "${DEBUG_PRERELS}" 2
        #echo "${RETVAL}"
        #exit

        string-repeat "${DEBUG_STRINGS}" 50 $'\n'
        echo "${RETVAL}" | wc -l
        #string-get-lines "${RETVAL}" 0 20
        debug-benchmark
        version-latest "${RETVAL}"
        echo "${RETVAL}"
        exit

        #for i in {1..5}
        #do
        #    STRINGS+=$'\n'"${DEBUG_STRINGS}"
        #    string-count-lines "${STRINGS}"
        #    echo "Lines: ${RETVAL}"
        #    version-latest "${STRINGS}"
        #    echo "Output: ${RETVAL}"
        #    debug-benchmark
        #done
        #exit

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
