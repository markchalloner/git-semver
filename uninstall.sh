#!/bin/bash
GIT_SEMVER=/usr/local/bin/git-semver
if [ -f ${GIT_SEMVER} ]
then
    rm ${GIT_SEMVER}
fi
