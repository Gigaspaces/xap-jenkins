#!/bin/bash
set -e

if [[ -z "${ORIG_PATH}" ]]; then
    export ORIG_PATH="${PATH}"
fi

function use_elm_version {
    local elmVersion=$1
    local globalDir="/home/jenkins/.npm-global_${elmVersion}"
    if [[ ! -e "${globalDir}" ]]; then echo "Elm version ${elmVersion} does not exist (${globalDir})";exit 1; fi
    export PATH="${globalDir}/bin:${ORIG_PATH}"
}
export -f use_elm_version

function install_elm {
    local elmVersion=$1
    local globalDir="/home/jenkins/.npm-global_${elmVersion}"
    export PATH="${globalDir}/bin:${PATH}"
    if [[ -e "${globalDir}" ]]; then echo "Elm version ${elmVersion} already exist"; exit 1; fi
    mkdir "${globalDir}"
    npm config set prefix "${globalDir}"
    if [[ "${elmVersion}" = "0.19.0" ]]
    then
        wget --no-verbose -O "${globalDir}"/elm.gz https://github.com/elm/compiler/releases/download/${elmVersion}/binary-for-linux-64-bit.gz
    elif [[ "${elmVersion}" = "0.18.0" ]]
    then
        wget --no-verbose -O "${globalDir}"/elm.gz https://github.com/elm-lang/elm-platform/releases/download/0.18.0-exp/elm-platform-linux-64bit.tar.gz
    fi
    gunzip "${globalDir}"/elm.gz
    chmod +x "${globalDir}"/elm
    use_elm_version ${elmVersion}
    #npm install -g elm@${elmVersion}
}

function install_elm_test {
    local elmVersion=$1
    local elmTestVersion=$2
    use_elm_version $1

    npm install -g elm-test@${elmTestVersion}
}

$@
