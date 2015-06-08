#!/bin/bash
pushd $(dirname $0) > /dev/null
DIR_SELF=$(pwd -P)
popd > /dev/null
GIT_SEMVER=/usr/local/bin/git-semver

ln -s ${DIR_SELF}/git-semver.sh ${GIT_SEMVER}
