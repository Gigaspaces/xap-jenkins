#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BUILDS_FILENAME="${DIR}/builds.txt"


function set_next_build_num {
	local buildNumber=$1

	if [ "${buildNumber}" == "" ]; then
	    echo "Error: missing build number. Usage: get_next_build_num <build number>"
        exit 1
	fi

	if [ ! -e "${BUILDS_FILENAME}" ]; then
	    echo "Builds file does not exist, path: ${BUILDS_FILENAME}. If this is the first run, please create empty file."
	    exit 1
	fi

	line=$(sed -n -e "/^${buildNumber}=/p" ${BUILDS_FILENAME})
	local next_build_num

	if [ "$line" == "" ]; then
		next_build_num=1
		echo "${buildNumber}=${next_build_num}" >> ${BUILDS_FILENAME}
	else
		num=$(echo $line | sed "s/${buildNumber}=\([0-9]*\)/\1/")
		next_build_num=$((num + 1))
		sed -i "s/${buildNumber}=$num\$/${buildNumber}=${next_build_num}/g" ${BUILDS_FILENAME}
	fi
	export CUSTOM_BUILD_NUMBER=${next_build_num}
}

# FILENAME is the path for file to write the variables to
if [ "${FILENAME}" == "" ]; then
    echo "FILENAME env var is not set"
    exit 1
fi

BUILD_NUMBER_KEY="$1"

if [ "${BUILD_NUMBER_KEY}" == "" ]; then
    echo "Error: missing build number. Usage: ./calculate_build_number.sh <build number>"
    exit 1
fi


set_next_build_num ${BUILD_NUMBER_KEY}
if [ "$?" != "0" ]; then
    echo "Failed to calculate build number"
    exit 1
fi
echo "BUILD_NUMBER=${CUSTOM_BUILD_NUMBER}" > ${FILENAME}


git add ${BUILDS_FILENAME}
git commit -m "updating ${BUILDS_FILENAME}. Setting latest build of ${BUILD_NUMBER_KEY} to be ${CUSTOM_BUILD_NUMBER}"
git push --set-upstream origin master