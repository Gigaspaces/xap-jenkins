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

    use_elm_version ${elmVersion}
    npm install -g elm@${elmVersion}
}


$@