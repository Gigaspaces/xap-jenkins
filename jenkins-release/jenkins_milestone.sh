#!/bin/bash

function log {
    echo "[INFO] $@"
}

function error_and_exit {
    echo "[ERROR] $@"
    exit 1
}
function to_job_url {
    local job="$1"
    echo job/${job//\//\/job\/}
}

function check_jenkins_job_exists {
    local jenkins_job=$(to_job_url "$1")
    #Get the current configuration and save it locally
    curl -f -s -X GET ${JENKINS_URL}/${jenkins_job}/config.xml >> /dev/null
    return $?
}

function get_jenkins_job_config {
    local jenkins_job=$(to_job_url "$1")
    local jenkins_config_file="$2"
    #Get the current configuration and save it locally
    curl -f -s -X GET ${JENKINS_URL}/${jenkins_job}/config.xml -o ${jenkins_config_file}
    local r="$?"
    if [ "$r" -ne 0 ]
    then
        echo "[ERROR] Failed to get job config of ${jenkins_job}, exit code is: $r"
        exit "$r"
    fi
}

function copy_jenkins_job {
    local from_job_name="$1"
    local to_job_name="$2"

    local origin_job_path=$(to_job_url $(get_job_parent ${from_job_name}))
    local origin_job_name=$(get_job_name ${from_job_name})
    local new_job_url="${origin_job_path}/job/${to_job_name}"

    curl -f -s --data ' ' "${JENKINS_URL}/${origin_job_path}/createItem?name="${to_job_name}"&mode=copy&from="${origin_job_name}
    local r="$?"
    if [ "$r" -ne 0 ]
    then
        echo "[ERROR] Failed to copy job ${from_job_name} to ${to_job_name}, exit code is: $r"
        exit "$r"
    fi

    curl -s --data disable "${JENKINS_URL}/${new_job_url}/disable"
	curl -s --data enable "${JENKINS_URL}/${new_job_url}/enable"

}

function post_jenkins_job_config {
    local jenkins_job=$(to_job_url "$1")
    local jenkins_config_file="$2"
    #Update the configuration via posting a local configuration file
    curl -f -X POST ${JENKINS_URL}/${jenkins_job}/config.xml --data-binary "@"$jenkins_config_file""
    local r="$?"
    if [ "$r" -ne 0 ]
    then
        echo "[ERROR] Failed to update job ${jenkins_job}, exit code is: $r"
        exit "$r"
    fi
}

function delete_jenkins_job {
    local jenkins_job=$(to_job_url "$1")
    curl -f -X POST ${JENKINS_URL}/${jenkins_job}/doDelete
    local r="$?"
    if [ "$r" -ne 0 ]
    then
        echo "[ERROR] Failed to delete job ${jenkins_job}, exit code is: $r"
        exit "$r"
    fi
}

function rename_job {
    local old_name=$(to_job_url "$1")
    local new_name="$2"

    curl -f -X POST ${JENKINS_URL}/${old_name}/doRename?newName=${new_name}
    local r="$?"
    if [ "$r" -ne 0 ]
    then
        echo "[ERROR] Failed to rename job ${old_name} to ${new_name}, exit code is: $r"
        exit "$r"
    fi
}

function get_default_value {
    local key="$1"
    local config_file="$2"
    local version_number=$(sed -n "/<name>${key}<\/name>/{N; /.*/{N; /<defaultValue>.*<\/defaultValue>/p}}" "$config_file" | grep defaultValue | sed -n '/defaultValue/{s/.*<defaultValue>\(.*\)<\/defaultValue>.*/\1/;p}')
    echo ${version_number}
}


function get_job_parent {
    local jobname="$1"
    local temp=$(echo $jobname | rev)

    if [ "$(expr index "$temp" '/')" == 0 ]; then
        echo ""
    else
        echo ${jobname:0:$(( ${#jobname} - $(expr index "$temp" '/') ))}
    fi


}

function get_job_name {
    local jobname="$1"
    local temp=$(echo $jobname | rev)

    if [ "$(expr index "$temp" '/')" == 0 ]; then
        echo "${jobname}"
    else
        echo ${jobname:$(( ${#jobname} - $(expr index "$temp" '/') + 1 ))}
    fi
}


function update_parameter {
    local jenkins_config_file="$1"
    local key="$2"
    local new_value="$3"

    sed -i "/<name>${key}<\/name>/{N; /.*/{N; s/<defaultValue>.*<\/defaultValue>/<defaultValue>"${new_value}"<\/defaultValue>/}}" "$jenkins_config_file"

    local current_value=$(sed -n "/<name>${key}<\/name>/{N; /.*/{N; /<defaultValue>.*<\/defaultValue>/p}}" "$jenkins_config_file" | grep defaultValue | sed -n '/defaultValue/{s/.*<defaultValue>\(.*\)<\/defaultValue>.*/\1/;p}')

    if [ "${current_value}" == "" ]; then
        echo "[ERROR] no such parameter [${key}] in ${jenkins_config_file}"
        exit 1
    fi

    local r="$?"
    if [ "$r" -ne 0 ]
    then
        echo "[ERROR] Failed to update parameter ${key} to ${new_value} in ${jenkins_config_file}, exit code is: $r"
        exit "$r"
    fi
}

function update_mode {
    local jenkins_config_file="$1"
    local mode="$2"
    sed -i '/<a class="string-array">/{N; s/<string>.*<\/string>/<string>'"$mode"'<\/string>/}' "$jenkins_config_file"

    local r="$?"
    if [ "$r" -ne 0 ]
    then
        echo "[ERROR] Failed to update mode to ${mode} in ${jenkins_config_file}, exit code is: $r"
        exit "$r"
    fi
}

function start_jenkins_timer_trigger {
    local jenkins_config_file="$1"
    local cron_pattern="$2"

    sed -i '/<hudson.triggers.TimerTrigger>/{N; s/<spec>.*<\/spec>/<spec>'"$cron_pattern"'<\/spec>/g;s/<spec\/>/<spec>'"$cron_pattern"'<\/spec>/g}' "$jenkins_config_file"
    local r="$?"
    if [ "$r" -ne 0 ]
    then
        echo "[ERROR] Failed to start_timer_trigger [${cron_pattern}] in ${jenkins_config_file}, exit code is: $r"
        exit "$r"
    fi
}

function stop_timer_trigger {
    local jenkins_config_file="$1"
    sed -i '/<hudson.triggers.TimerTrigger>/{N; s/<spec>.*<\/spec>/<spec><\/spec>/}' "$jenkins_config_file"
    local r="$?"
    if [ "$r" -ne 0 ]
    then
        echo "[ERROR] Failed to stop_timer_trigger in ${jenkins_config_file}, exit code is: $r"
        exit "$r"
    fi
}

function append_branch_to_newman_cron {
    local branch="$1"
    export SSHPASS=password
    sshpass -e ssh "$XAP_NEWMAN_USER"@"$XAP_NEWMAN_HOST" -C "sed -ri 's/crons.suitediff.branch = .*/crons.suitediff.branch = '$branch'/'g /home/xap/newman-analytics/resources/crons/suitediff/suitediff.properties"
}

function move_to_release_mode {

    log "Checking existence of ${CONTINUOUS_JOB}"
    check_jenkins_job_exists "${CONTINUOUS_JOB}"
    if [ "$?" != "0" ]; then
        echo "[ERROR] ${CONTINUOUS_JOB} does not exist"
        exit 1
    fi

    log "Checking existence of ${RELEASE_JOB}"
    check_jenkins_job_exists "${RELEASE_JOB}"
    if [ "$?" != "0" ]; then
        echo "[ERROR] ${RELEASE_JOB} does not exist"
        exit 1
    fi

    log "Checking existence of ${CONTINUOUS_MILESTONE_JOB}"
    check_jenkins_job_exists "${CONTINUOUS_MILESTONE_JOB}"
    if [ "$?" == "0" ]; then
        echo "[ERROR] ${CONTINUOUS_MILESTONE_JOB} job already exists"
        exit 1
    fi

    log "Checking existence of ${RELEASE_MILESTONE_JOB}"
    check_jenkins_job_exists "${RELEASE_MILESTONE_JOB}"
    if [ "$?" == "0" ]; then
        echo "[ERROR] ${RELEASE_MILESTONE_JOB} job already exists"
        exit 1
    fi

    log "Getting configuration files of ${CONTINUOUS_JOB} and ${RELEASE_JOB}"
    get_jenkins_job_config "${CONTINUOUS_JOB}" "continuous.xml"
    get_jenkins_job_config "${RELEASE_JOB}" "release.xml"
    cp continuous.xml continuous-milestone.xml
    cp release.xml release-milestone.xml

    CURRENT_MILESTONE=$(get_default_value "MILESTONE" "continuous-milestone.xml")
    log "Current milestone is: ${CURRENT_MILESTONE}"

    #Prev cont
    log "[CONTINUOUS-MILESTONE] Updating BRANCH_NAME to ${MILESTONE_BRANCH_NAME}"
    update_parameter "continuous-milestone.xml" "BRANCH_NAME" "${MILESTONE_BRANCH_NAME}"

    #New Cont
    log "[CONTINUOUS] Updating XAP_VERSION to ${NEXT_XAP_VERSION}"
    update_parameter "continuous.xml" "XAP_VERSION" "${NEXT_XAP_VERSION}"
    log "[CONTINUOUS] Updating MILESTONE to ${NEXT_MILESTONE}"
    update_parameter "continuous.xml" "MILESTONE" "${NEXT_MILESTONE}"
    log "[CONTINUOUS] Updating XAP_BUILD_NUMBER to ${NEXT_XAP_BUILD_NUMBER}"
    update_parameter "continuous.xml" "XAP_BUILD_NUMBER" "${NEXT_XAP_BUILD_NUMBER}"

    #Old release
    log "[RELEASE-MILESTONE] Stopping timer trigger"
    stop_timer_trigger "release-milestone.xml"
    log "[RELEASE-MILESTONE] Updating BRANCH_NAME ${MILESTONE_BRANCH_NAME}"
    update_parameter "release-milestone.xml" "BRANCH_NAME" "${MILESTONE_BRANCH_NAME}"
    update_parameter "release-milestone.xml" "TAG_NAME" "\$XAP_VERSION-\$MILESTONE"
    update_mode "release-milestone.xml" "MILESTONE"

    #New release
    stop_timer_trigger "release.xml"
    update_parameter "release.xml" "XAP_VERSION" "${NEXT_XAP_VERSION}"
    update_parameter "release.xml" "MILESTONE" "${NEXT_MILESTONE}"
    update_parameter "release.xml" "XAP_BUILD_NUMBER" "${NEXT_XAP_BUILD_NUMBER}"

    rename_job "${CONTINUOUS_JOB}" "${CONTINUOUS_MILESTONE_JOB_NAME}"
    copy_jenkins_job "${CONTINUOUS_MILESTONE_JOB}" "${CONTINUOUS_JOB_NAME}"

    rename_job "${RELEASE_JOB}" "${RELEASE_MILESTONE_JOB_NAME}"
    copy_jenkins_job "${RELEASE_MILESTONE_JOB}" "${RELEASE_JOB_NAME}"


    post_jenkins_job_config "${CONTINUOUS_JOB}" "continuous.xml"
    post_jenkins_job_config "${CONTINUOUS_MILESTONE_JOB}" "continuous-milestone.xml"
    post_jenkins_job_config "${RELEASE_JOB}" "release.xml"
    post_jenkins_job_config "${RELEASE_MILESTONE_JOB}" "release-milestone.xml"

    append_branch_to_newman_cron "${MILESTONE_BRANCH_NAME}"
}

function move_to_nightly {

    check_jenkins_job_exists "${RELEASE_JOB}"
    if [ "$?" != "0" ]; then
        echo "[ERROR] ${RELEASE_JOB} job does not exist"
        exit 1
    fi

    check_jenkins_job_exists "${CONTINUOUS_MILESTONE_JOB}"
    if [ "$?" != "0" ]; then
        echo "[ERROR] ${CONTINUOUS_MILESTONE_JOB} job does not exist"
        exit 1
    fi

    check_jenkins_job_exists "${RELEASE_MILESTONE_JOB}"
    if [ "$?" != "0" ]; then
        echo "[ERROR] ${RELEASE_MILESTONE_JOB} job does not exist"
        exit 1
    fi

    get_jenkins_job_config "${RELEASE_JOB}" "release.xml"
    start_jenkins_timer_trigger "release.xml" "H 17 * * *"
    post_jenkins_job_config "${RELEASE_JOB}" "release.xml"


    delete_jenkins_job "${CONTINUOUS_MILESTONE_JOB}"
    delete_jenkins_job "${RELEASE_MILESTONE_JOB}"

    append_branch_to_newman_cron "master"
}

function stop_nightly_trigger {
    check_jenkins_job_exists "${RELEASE_JOB}"
    if [ "$?" != "0" ]; then
        echo "[ERROR] ${RELEASE_JOB} job does not exist"
        exit 1
    fi
    get_jenkins_job_config "${RELEASE_JOB}" "release.xml"
    stop_timer_trigger "release.xml"
    post_jenkins_job_config "${RELEASE_JOB}" "release.xml"


}

function set_env_vars {

    if [ "${JENKINS_URL}" == "" ]; then
        error_and_exit "JENKINS_URL is not set"
    fi

    if [ "${MILESTONE_BRANCH_NAME}" == "" ]; then
        error_and_exit "MILESTONE_BRANCH_NAME is not set"
    fi

    if [ "${NEXT_XAP_VERSION}" == "" ]; then
        error_and_exit "NEXT_XAP_VERSION is not set"
    fi

    if [ "${NEXT_MILESTONE}" == "" ]; then
        error_and_exit "NEXT_MILESTONE is not set"
    fi

    if [ "${NEXT_XAP_BUILD_NUMBER}" == "" ]; then
        error_and_exit "NEXT_XAP_BUILD_NUMBER is not set"
    fi


    if [ "${CONTINUOUS_JOB_NAME}" == "" ]; then
        error_and_exit "CONTINUOUS_JOB_NAME is not set"
    fi

    if [ "${CONTINUOUS_MILESTONE_JOB_NAME}" == "" ]; then
        error_and_exit "CONTINUOUS_MILESTONE_JOB_NAME is not set"
    fi

    if [ "${RELEASE_JOB_NAME}" == "" ]; then
        error_and_exit "RELEASE_JOB_NAME is not set"
    fi

    if [ "${RELEASE_MILESTONE_JOB_NAME}" == "" ]; then
        error_and_exit "RELEASE_MILESTONE_JOB_NAME is not set"
    fi

    if [ "${XAP_NEWMAN_USER}" == "" ]; then
        error_and_exit "XAP_NEWMAN_USER is not set"
    fi

    if [ "${XAP_NEWMAN_HOST}" == "" ]; then
        error_and_exit "XAP_NEWMAN_HOST is not set"
    fi


    CONTINUOUS_JOB="${CONTINUOUS_JOB_NAME}"
    CONTINUOUS_MILESTONE_JOB="${CONTINUOUS_MILESTONE_JOB_NAME}"
    RELEASE_JOB="${RELEASE_JOB_NAME}"
    RELEASE_MILESTONE_JOB="${RELEASE_MILESTONE_JOB_NAME}"
    if [ "${FOLDER}" != "" ]; then
        CONTINUOUS_JOB="${FOLDER}/${CONTINUOUS_JOB}"
        CONTINUOUS_MILESTONE_JOB="${FOLDER}/${CONTINUOUS_MILESTONE_JOB}"
        RELEASE_JOB="${FOLDER}/${RELEASE_JOB}"
        RELEASE_MILESTONE_JOB="${FOLDER}/${RELEASE_MILESTONE_JOB}"
    fi
}


# Example of env vars setup
#    FOLDER="12.3.0/master"
#    CONTINUOUS_JOB_NAME="continuous"
#    CONTINUOUS_MILESTONE_JOB_NAME="continuous-milestone"
#    RELEASE_JOB_NAME="release"
#    RELEASE_MILESTONE_JOB_NAME="release-milestone"

#    JENKINS_URL="http://${JENKINS_USER}:${JENKINS_PASSWORD}@${JENKINS_HOST}:${JENKINS_PORT}"
#    NEXT_XAP_VERSION="12.3.0"
#    CURRENT_MILESTONE="m6"
#    NEXT_MILESTONE="m7"
#    NEXT_XAP_BUILD_NUMBER="18906"
#    MILESTONE_BRANCH_NAME="12.3.0-${CURRENT_BRANCH}-branch"
#    MODE="CREATE_MILESTONE_JOBS"

set_env_vars

if [ "${MODE}" == "CREATE_MILESTONE_JOBS" ]; then
    move_to_release_mode
elif [ "${MODE}" == "DELETE_MILESTONE_JOBS" ]; then
    move_to_nightly
elif [ "${MODE}" == "STOP_NIGHTLY_TRIGGER" ]; then
    stop_nightly_trigger
else
    echo "[ERROR] unknown mode ${MODE}"
    exit 1
fi
