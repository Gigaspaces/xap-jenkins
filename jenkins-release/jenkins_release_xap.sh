#!/bin/bash

function release_xap {
    local xap_open_url="git@github.com:Gigaspaces/xap-open.git"
    local xap_url="git@github.com:Gigaspaces/xap.git"
    local xap_open_folder="$(get_folder $xap_open_url)"
    local xap_folder="$(get_folder $xap_url)"

    printenv

    announce_step "clone xap-open"
    clone "$xap_open_url"
    announce_step "clone xap"
    clone "$xap_url"

    announce_step "creating branch xap-open"
    create_release_branch "$xap_open_folder"
    announce_step "creating branch xap"
    create_release_branch "$xap_folder"

    #disable all jobs
    announce_step "disabling xap-release and xap-continuous jenkins jobs"
    get_jenkins_job_config "xap-release" "xap_release_config.xml"
    get_jenkins_job_config "xap-continuous" "xap_continuous_config.xml"
    stop_jenkins_triggers "xap_release_config.xml"
    stop_jenkins_triggers "xap_continuous_config.xml"
    post_jenkins_job_config "xap-release" "xap_release_config.xml"
    post_jenkins_job_config "xap-continuous" "xap_continuous_config.xml"

    #jenkins xap-release job
    announce_step "updating xap-release mode to MILESTONE and BRANCH_NAME to $BRANCH_NAME and trigger to 0 16 * * *"
    get_jenkins_job_config "xap-release" "xap_release_config.xml"
    change_mode "MILESTONE" "xap_release_config.xml"
    change_branch "$BRANCH_NAME" "xap_release_config.xml"
    start_jenkins_triggers "xap_release_config.xml" "0 16 * * *"
    post_jenkins_job_config "xap-release" "xap_release_config.xml"

    #jenkins xap-continuous job - xap-continuous is disabled do also xap-continuous-master is disabled
    announce_step "coping xap-continuous to xap-continuous-master"
    copy_jenkins_job "xap-continuous" "xap-continuous-master"

    announce_step "incrementing XAP_BUILD_NUMBER at xap-continuous-master"
    get_jenkins_job_config "xap-continuous-master" "xap_continuous_master_config.xml"
    increment_build_number "xap_continuous_master_config.xml"
    post_jenkins_job_config "xxap-continuous-master" "xap_continuous_master_config.xml"

    announce_step "changing BRANCH_NAME to $BRANCH_NAME at xap-continuous job and trigger to * * * * *"
    get_jenkins_job_config "xap-continuous" "xap_continuous_config.xml"
    change_branch "$BRANCH_NAME" "xap_continuous_config.xml"
    start_jenkins_triggers "xap_continuous_config.xml" "* * * * *"
    post_jenkins_job_config "xap-continuous" "xap_continuous_config.xml"

    announce_step "add branch $BRANCH_NAME to newman reporter cron"
    append_branch_to_newman_cron "$BRANCH_NAME"
}

function back_to_nightly_release_xap {

    #disable all jobs
    announce_step "disabling xap-release,xap-continuous-master and xap-continuous jenkins jobs"
    get_jenkins_job_config "xap-release" "xap_release_config.xml"
    get_jenkins_job_config "xap-continuous" "xap_continuous_config.xml"
    get_jenkins_job_config "xap-continuous-master" "xap_continuous_master_config.xml"
    stop_jenkins_triggers "xap_release_config.xml"
    stop_jenkins_triggers "xap_continuous_config.xml"
    stop_jenkins_triggers "xap_continuous_master_config.xml"
    post_jenkins_job_config "xap-release" "xap_release_config.xml"
    post_jenkins_job_config "xap-continuous" "xap_continuous_config.xml"
    post_jenkins_job_config "xap-continuous-master" "xap_continuous_master_config.xml"

    announce_step "updating xap-release mode to NIGHTLY and BRANCH_NAME to master and trigger to 0 16 * * *"
    get_jenkins_job_config "xap-release" "xap_release_config.xml"
    change_mode "NIGHTLY"
    change_branch "master"
    start_jenkins_triggers "xap_release_config.xml" "0 16 * * *"
    increment_build_number "xap_continuous_master_config.xml"
    post_jenkins_job_config "xap-release" "xap_release_config.xml"

    announce_step "delete xap-continuous job"
    delete_jenkins_job "xap-continuous"

    announce_step "coping xap-continuous-master to xap-continuous"
    copy_jenkins_job "xap-continuous-master" "xap-continuous"

    announce_step "deleting xap-continuous-master"
    delete_jenkins_job "xap-continuous-master"

    announce_step "updating xap-continuous trigger to * * * * *"
    get_jenkins_job_config "xap-continuous" "xap_continuous_config.xml"
    start_jenkins_triggers "xap_continuous_config.xml" "* * * * *"
    post_jenkins_job_config "xap-continuous" "xap_continuous_config.xml"

    announce_step "return branch master to newman reporter cron"
    append_branch_to_newman_cron "master"
}

function copy_jenkins_job {
    local job_name="$1"
    local new_job_name="$2"
    cmd="curl -X POST http://"$JENKINS_HOST":"$JENKINS_PORT"/createItem?name="$new_job_name"&mode=copy&from="$job_name""
    eval $cmd
    if [ "$r" -ne 0 ]
    then
        echo "[ERROR] Failed to copy $job_name to $new_job_name, cmd: $cmd, exit code is: $r"
        exit "$r"
    fi
}

function delete_jenkins_job {
    local job_name="$1"
    cmd="curl -X POST http://"$JENKINS_HOST":"$JENKINS_PORT"/job/"$job_name"/deDelete"
    eval $cmd
    if [ "$r" -ne 0 ]
    then
        echo "[ERROR] Failed to delete jenkins job $job_name, cmd: $cmd, exit code is: $r"
        exit "$r"
    fi
}

function stop_jenkins_triggers{
    local jenkins_config_file="$1"
    sed -i '/<hudson.triggers.TimerTrigger>/{N; s/<spec>.*<\/spec>/<spec><\/spec>/}' "$jenkins_config_file"
    sed -i '/<hudson.triggers.SCMTrigger>/{N; s/<spec>.*<\/spec>/<spec><\/spec>/}' "$jenkins_config_file"
}

function start_jenkins_triggers{
    local jenkins_config_file="$1"
    local cron_pattern="$2"

    sed -i '/<hudson.triggers.TimerTrigger>/{N; s/<spec>.*<\/spec>/<spec>'$cron_pattern'<\/spec>/}' "$jenkins_config_file"
    sed -i '/<hudson.triggers.SCMTrigger>/{N; s/<spec>.*<\/spec>/<spec>'$cron_pattern'<\/spec>/}' "$jenkins_config_file"
}

function append_branch_to_newman_cron{
    local branch="$1"
    sshpass -e ssh "$XAP_NEWMAN_USER"@"$XAP_NEWMAN_HOST" -C "sed -ri 's/crons.suitediff.branch = .*/crons.suitediff.branch = '$branch'/'g /home/xap/newman-analytics/resources/crons/suitediff/suitediff.properties"
}

function get_jenkins_job_config{
    local jenkins_job="$1"
    local jenkins_config_file="$2"
    #Get the current configuration and save it locally
    cmd="curl -X GET http://"$JENKINS_USER":"$JENKINS_PASSWORD"@"$JENKINS_HOST":"$JENKINS_PORT"/job/"$jenkins_job"/config.xml -o "$jenkins_config_file""
    eval $cmd
    if [ "$r" -ne 0 ]
    then
        echo "[ERROR] Failed to get jenkins config $jenkins_job, cmd: $cmd, exit code is: $r"
        exit "$r"
    fi
}

function post_jenkins_job_config{
    local jenkins_job="$1"
    local jenkins_config_file="$2"
    #Update the configuration via posting a local configuration file
    cmd="curl -X POST http://"$JENKINS_USER":"$JENKINS_PASSWORD"@"$JENKINS_HOST":"$JENKINS_PORT"/job/"$jenkins_job"/config.xml --data-binary "@"$jenkins_config_file"""
    eval $cmd
    if [ "$r" -ne 0 ]
    then
        echo "[ERROR] Failed to get jenkins config $jenkins_job, cmd: $cmd, exit code is: $r"
        exit "$r"
    fi
}

function increment_build_number{
    local jenkins_config_file="$1"
    local version_number=$(sed -n '/<name>XAP_BUILD_NUMBER<\/name>/{N; /.*/{N; /<defaultValue>.*<\/defaultValue>/p}}' "$jenkins_config_file" | grep defaultValue | sed -n '/defaultValue/{s/.*<defaultValue>\(.*\)<\/defaultValue>.*/\1/;p}')
    (($version_number++))
    sed -i '/<name>XAP_BUILD_NUMBER<\/name>/{N; /.*/{N; s/<defaultValue>.*<\/defaultValue>/<defaultValue>'$version_number'<\/defaultValue>/}}' "$jenkins_config_file"
}

function change_mode{
    local mode="$1"
    local jenkins_config_file="$2"
    sed -i '/<a class="string-array">/{N; s/<string>.*<\/string>/<string>'"$mode"'<\/string>/}' "$jenkins_config_file"
}

function change_branch{
    local branch="$1"
    local jenkins_config_file="$2"
    sed -i '/<name>BRANCH_NAME<\/name>/{N; /.*/{N; s/<defaultValue>.*<\/defaultValue>/<defaultValue>'"$branch"'<\/defaultValue>/}}' "$jenkins_config_file"
}

function create_release_branch {
    local git_folder="$1"
    local commit_sh="$2"

    (
	cd "$git_folder"

	if [ -z "$commit_sh" ]
	then
	    git branch "$BRANCH_NAME" "$commit_sh"
	else
	    git branch "$BRANCH_NAME"
	fi
	git checout "$BRANCH_NAME"
	git push --set-upstream origin "$BRANCH_NAME"
    )
}



function clone {
    local url="$1"
    local folder="$(get_folder $1)"

    if [ -d "$folder" ]
    then
        cd "$folder"
        git pull
        git rebase
    fi
    rm -rf "$folder"
    git clone "$url" "$folder"
}

# Get the folder from git url
# $1 is a git url of the form git@github.com:Gigaspaces/xap-open.git
# The function will return a folder in the $WORKSPACE that match this git url (for example $WORKSPACE/xap-open)
function get_folder {
    echo -n "$WORKSPACE/$(echo -e $1 | sed 's/.*\/\(.*\)\.git/\1/')"
}

let step=1
function announce_step {
    local tooks=""
    if [ -z ${last_step+x} ]
    then
       let start_time=$(date +'%s')
    else
	local seconds="$(($(date +'%s') - $start_time))"
	local formatted=`date -u -d @${seconds} +"%T"`
	tooks="$last_step tooks: $formatted (hh:mm:ss)"
    fi
    last_step=$1

    if [ "" != "$tooks" ]
    then
	echo ""
	echo ""
	echo "############################################################################################################################################################"
	echo "############################################################################################################################################################"
	echo "#                                                  $tooks"
	echo "############################################################################################################################################################"
	echo "############################################################################################################################################################"
    fi
    echo ""
    echo ""
    echo ""
    echo "************************************************************************************************************************************************************"
    echo "************************************************************************************************************************************************************"
    echo "*                                                      Step [$step]: $1"
    echo "************************************************************************************************************************************************************"
    echo "************************************************************************************************************************************************************"
    (( step++ ))
    let start_time=$(date +'%s')
}
