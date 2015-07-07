#!/bin/bash
dirs=("${HOME}/bin" "/usr/local/bin" "/usr/bin" "/bin")
for i in "${dirs[@]}"
do
    GIT_SEMVER=${i}/git-semver
    if [ -f ${GIT_SEMVER} ]
    then
        rm ${GIT_SEMVER}
    fi
done

if [ "$1" == "-p" ] || [ "$1" == "--purge" ]
then
    rm -rf ${HOME}/.git-semver
fi
