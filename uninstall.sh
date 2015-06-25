#!/bin/bash
dirs=("/usr/local/bin" "/usr/bin" "/bin")
for i in "${dirs[@]}"
do
    GIT_SEMVER=${i}/git-semver
    if [ -f ${GIT_SEMVER} ]
    then
        rm ${GIT_SEMVER}
    fi
done
