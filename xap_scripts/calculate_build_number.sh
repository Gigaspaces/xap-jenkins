#!/bin/bash


BUILDS_FILENAME=${BUILDS_FILENAME="builds.txt"}


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

if [ "$1" == "" ]; then
    echo "Error: missing build number. Usage: ./calculate_build_number.sh <build number>"
    exit 1
fi


set_next_build_num $1
if [ "$?" != "0" ]; then
    echo "Failed to calculate build number"
    exit 1
fi
echo "BUILD_NUMBER=${CUSTOM_BUILD_NUMBER}" > ${FILENAME}
echo "XAP_VERSION=${OVERRIDE_XAP_VERSION=$XAP_VERSION}" >> ${FILENAME}
echo "MILESTONE=${OVERRIDE_MILESTONE=$MILESTONE}" >> ${FILENAME}
echo "XAP_BUILD_NUMBER=${OVERRIDE_XAP_BUILD_NUMBER=$XAP_BUILD_NUMBER}" >> ${FILENAME}
echo "BRANCH_NAME=${OVERRIDE_BRANCH_NAME=$BRANCH_NAME}" >> ${FILENAME}
