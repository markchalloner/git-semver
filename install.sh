#!/bin/bash
pushd $(dirname $0) > /dev/null
DIR_SELF=$(pwd -P)
popd > /dev/null
dirs=("$HOME/bin" "/usr/local/bin" "/usr/bin" "/bin")
for i in "${dirs[@]}"
do
    if [ -d "${i}" ] && $(echo $PATH | grep -q "${i}")
    then
        DIR_BIN="${i}"
        break;
    fi
done

GIT_SEMVER=${DIR_BIN}/git-semver
if [ -f ${GIT_SEMVER} ]
then
    rm ${GIT_SEMVER}
fi
ln -s ${DIR_SELF}/git-semver.sh ${GIT_SEMVER}
