#!/bin/bash
set -e

function use_elm_version {
    local elmVersion=$1
    local globalDir="/home/jenkins/.npm-global_${elmVersion}"
    if [[ ! -e "${globalDir}" ]]; then echo "Elm version ${elmVersion} does not exist (${globalDir})";exit 1; fi
}
export -f use_elm_version

function install_elm {
    local elmVersion=$1
    local globalDir="/home/jenkins/.npm-global_${elmVersion}/bin"
    if [[ -e "${globalDir}" ]]; then echo "Elm version ${elmVersion} already exist"; exit 1; fi
    mkdir -p "${globalDir}"
    if [[ "${elmVersion}" = "0.19.0" ]]
    then
        wget --no-verbose -O "${globalDir}"/elm.gz https://github.com/elm/compiler/releases/download/${elmVersion}/binary-for-linux-64-bit.gz
    elif [[ "${elmVersion}" = "0.18.0" ]]
    then
        wget --no-verbose -O "${globalDir}"/elm.gz https://github.com/elm-lang/elm-platform/releases/download/0.18.0-exp/elm-platform-linux-64bit.tar.gz
    fi
    gunzip "${globalDir}"/elm.gz
    chmod +x "${globalDir}"/elm
}

function install_elm_test {
    local elmVersion=$1
    local elmTestVersion=$2
    local globalDir="/home/jenkins/.npm-global_${elmVersion}"
    npm config set prefix "${globalDir}"
    npm install -g elm-test@${elmTestVersion}
}

$@
