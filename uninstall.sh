#!/bin/bash

readonly DIR_HOME=${HOME}

dirs=("${DIR_HOME}/.local/bin" "${DIR_HOME}/bin" "/usr/local/bin" "/usr/bin" "/bin")
for i in "${dirs[@]}"
do
    GIT_SEMVER=${i}/git-semver
    if [ -f "${GIT_SEMVER}" ]
    then
        rm "${GIT_SEMVER}"
    fi
done

if [ "$1" == "-p" ] || [ "$1" == "--purge" ]
then
    DIR_CONF_DEST="${XDG_CONFIG_HOME:-$DIR_HOME}/.git-semver"
    DIR_DATA="${XDG_DATA_HOME:-$DIR_HOME}/.git-semver"
    
    rm -rf "${DIR_CONF_DEST}" "${DIR_DATA}"
fi
