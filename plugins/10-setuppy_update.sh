#!/bin/bash

function run() {

    local version_new="$1"
    local git_root="$5"

    local setuppy_path="${git_root}/setup.py"

    if [ ! -e "${setuppy_path}" ]
    then
        echo "Could not find setup.py on the project root."
        return 112
    fi

    tmpfile=$(mktemp)
    # Extended regexs are purposely avoided for Mac OS and Free BSD compatbility.
    sed "s/version[[:blank:]]*=[[:blank:]]*[\"'][0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*[\"'][[:blank:]]*,/version=\"${version_new}\",/" < "${git_root}/setup.py" > "${tmpfile}"
    cat "${tmpfile}" > "${setuppy_path}"
    rm -f "${tmpfile}"

    git add "${setuppy_path}"
    git commit "${setuppy_path}" -m "Updated setup.py version"
    return 0

}

case "${1}" in
    --about)
        echo -n "Change the version argument of the project's setup.py to the new created version."
        ;;
    *)
        run "$@"
        ;;
esac
