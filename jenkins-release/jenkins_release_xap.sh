#!/bin/bash

set -e

source "$1"

function release_xap {
    local mode=$1

    #disable all jobs
    announce_step "disabling xap-release and xap-continuous jenkins jobs"
    get_jenkins_job_config "xap-release" "xap_release_config.xml"
    get_jenkins_job_config "xap-continuous" "xap_continuous_config.xml"
    stop_jenkins_all_trigger "xap_release_config.xml"
    stop_jenkins_all_trigger "xap_continuous_config.xml"
    post_jenkins_job_config "xap-release" "xap_release_config.xml"
    post_jenkins_job_config "xap-continuous" "xap_continuous_config.xml"



    #jenkins xap-release job
    announce_step "updating xap-release mode to $mode and BRANCH_NAME and triggers"
    get_jenkins_job_config "xap-release" "xap_release_config.xml"
    change_mode "$mode" "xap_release_config.xml"
    change_branch "\$XAP_VERSION-\$MILESTONE" "xap_release_config.xml"
    if [ "$MILESTONE" -eq "ga" ]
    then
        change_tag "\$XAP_VERSION-\$MILESTONE-RELEASE" "xap_release_config.xml"
    else
        change_tag "\$XAP_VERSION-\$MILESTONE-MILESTONE" "xap_release_config.xml"
    fi
    start_jenkins_timer_trigger "xap_release_config.xml" "0 17 * * *"
    post_jenkins_job_config "xap-release" "xap_release_config.xml"

    #jenkins xap-continuous job - xap-continuous is disabled do also xap-continuous-master is disabled
    announce_step "coping xap-continuous to xap-continuous-master"
    get_jenkins_job_config "xap-continuous" "xap_continuous_config.xml"
    copy_jenkins_job "xap-continuous" "xap-continuous-master"

    announce_step "incrementing XAP_BUILD_NUMBER at xap-continuous-master"
    get_jenkins_job_config "xap-continuous-master" "xap_continuous_master_config.xml"
    increment_build_number "xap_continuous_master_config.xml" "10"
    increment_milestone_number "xap_continuous_master_config.xml"
    post_jenkins_job_config "xap-continuous-master" "xap_continuous_master_config.xml"

    announce_step "updating xap-continuous BRANCH_NAME and triggers"
    get_jenkins_job_config "xap-continuous" "xap_continuous_config.xml"
    change_branch "\$XAP_VERSION-\$MILESTONE" "xap_continuous_config.xml"
    start_jenkins_timer_trigger "xap_continuous_config.xml" "0 6 * * *"
    start_jenkins_scm_trigger "xap_continuous_config.xml" "* * * * *"
    post_jenkins_job_config "xap-continuous" "xap_continuous_config.xml"

    #announce_step "add branch $BRANCH_NAME to newman reporter cron"
    append_branch_to_newman_cron "$VERSION"-"$MILESTONE"
}

function back_to_nightly_release_xap {

    #disable all jobs
    announce_step "disabling xap-release,xap-continuous-master and xap-continuous jenkins jobs"
    get_jenkins_job_config "xap-release" "xap_release_config.xml"
    get_jenkins_job_config "xap-continuous" "xap_continuous_config.xml"
    get_jenkins_job_config "xap-continuous-master" "xap_continuous_master_config.xml"
    stop_jenkins_all_trigger "xap_release_config.xml"
    stop_jenkins_all_trigger "xap_continuous_config.xml"
    stop_jenkins_all_trigger "xap_continuous_master_config.xml"
    post_jenkins_job_config "xap-release" "xap_release_config.xml"
    post_jenkins_job_config "xap-continuous" "xap_continuous_config.xml"
    post_jenkins_job_config "xap-continuous-master" "xap_continuous_master_config.xml"

    announce_step "updating xap-release mode to NIGHTLY and BRANCH_NAME to master and triggers"
    get_jenkins_job_config "xap-release" "xap_release_config.xml"
    change_mode "NIGHTLY" "xap_release_config.xml"
    change_branch "master" "xap_release_config.xml"
    start_jenkins_scm_trigger "xap_release_config.xml" "0 17 * * *"
    increment_milestone_number "xap_release_config.xml"
    increment_build_number "xap_release_config.xml" "1"
    change_tag "\$XAP_VERSION-\$MILESTONE-\$MODE" "xap_release_config.xml"
    post_jenkins_job_config "xap-release" "xap_release_config.xml"


    announce_step "delete xap-continuous job"
    delete_jenkins_job "xap-continuous"

    announce_step "coping xap-continuous-master to xap-continuous"
    get_jenkins_job_config "xap-continuous-master" "xap_continuous_master_config.xml"
    copy_jenkins_job "xap-continuous-master" "xap-continuous"

    announce_step "deleting xap-continuous-master"
    delete_jenkins_job "xap-continuous-master"

    announce_step "updating xap-continuous trigger to * * * * *"
    get_jenkins_job_config "xap-continuous" "xap_continuous_config.xml"
    start_jenkins_timer_trigger "xap_continuous_config.xml" "0 6 * * *"
    start_jenkins_scm_trigger "xap_continuous_config.xml" "* * * * *"
    post_jenkins_job_config "xap-continuous" "xap_continuous_config.xml"

    #announce_step "return branch master to newman reporter cron"
    append_branch_to_newman_cron "master"
}

function clone_repos {
    local xap_url="git@github.com:xap/xap.git"
    local xap_premium_url="git@github.com:Gigaspaces/xap-premium.git"
    local xap_dotnet_url="git@github.com:Gigaspaces/xap-dotnet.git"
    local xap_folder="$(get_folder $xap_url)"
    local xap_premium_folder="$(get_folder $xap_premium_url)"
    local xap_dotnet_folder="$(get_folder $xap_dotnet_url)"

    announce_step "clone xap"
    clone "$xap_url"
    announce_step "clone xap-premium"
    clone "$xap_premium_url"
    announce_step "clone xap dotnet"
    clone "$xap_dotnet_url"
}

function create_branches {
    local xap_url="git@github.com:xap/xap.git"
    local xap_premium_url="git@github.com:Gigaspaces/xap-premium.git"
    local xap_dotnet_url="git@github.com:Gigaspaces/xap-dotnet.git"

    local xap_folder="$(get_folder $xap_url)"
    local xap_premium_folder="$(get_folder $xap_premium_url)"
    local xap_dotnet_folder="$(get_folder $xap_dotnet_url)"

    announce_step "creating branch xap"
    create_release_branch "$xap_folder"
    announce_step "creating branch xap premium"
    create_release_branch "$xap_premium_folder"
    announce_step "creating branch xap dotnet"
    create_release_branch "$xap_dotnet_folder"

}
function copy_jenkins_job {
    local from_job_name="$1"
    local to_job_name="$2"

    curl -s --data ' ' "http://"$JENKINS_USER":"$JENKINS_PASSWORD"@"$JENKINS_HOST":"$JENKINS_PORT"/createItem?name="$to_job_name"&mode=copy&from="$from_job_name
    curl -s --data disable "http://"$JENKINS_USER":"$JENKINS_PASSWORD"@"$JENKINS_HOST":"$JENKINS_PORT"/job/$to_job_name/disable"
	curl -s --data enable "http://"$JENKINS_USER":"$JENKINS_PASSWORD"@"$JENKINS_HOST":"$JENKINS_PORT"/job/$to_job_name/enable"

    local r="$?"
    if [ "$r" -ne 0 ]
    then
        echo "[ERROR] Failed to copy $job_name to $new_job_name, exit code is: $r"
        exit "$r"
    fi
}

function delete_jenkins_job {
    local job_name="$1"
    cmd="curl -X POST http://"$JENKINS_USER":"$JENKINS_PASSWORD"@"$JENKINS_HOST":"$JENKINS_PORT"/job/"$job_name"/doDelete"
    eval "$cmd"
    local r="$?"
    if [ "$r" -ne 0 ]
    then
        echo "[ERROR] Failed to delete jenkins job $job_name, cmd: $cmd, exit code is: $r"
        exit "$r"
    fi
}

function stop_jenkins_all_trigger {
    local jenkins_config_file="$1"
    sed -i '/<hudson.triggers.TimerTrigger>/{N; s/<spec>.*<\/spec>/<spec><\/spec>/}' "$jenkins_config_file"
    sed -i '/<hudson.triggers.SCMTrigger>/{N; s/<spec>.*<\/spec>/<spec><\/spec>/}' "$jenkins_config_file"
}

function stop_jenkins_timer_trigger {
    local jenkins_config_file="$1"
    sed -i '/<hudson.triggers.TimerTrigger>/{N; s/<spec>.*<\/spec>/<spec><\/spec>/}' "$jenkins_config_file"
}

function stop_jenkins_scm_trigger {
    local jenkins_config_file="$1"
    sed -i '/<hudson.triggers.SCMTrigger>/{N; s/<spec>.*<\/spec>/<spec><\/spec>/}' "$jenkins_config_file"
}

function start_jenkins_timer_trigger {
    local jenkins_config_file="$1"
    local cron_pattern="$2"

    sed -i '/<hudson.triggers.TimerTrigger>/{N; s/<spec>.*<\/spec>/<spec>'"$cron_pattern"'<\/spec>/g;s/<spec\/>/<spec>'"$cron_pattern"'<\/spec>/g}' "$jenkins_config_file"
}

function start_jenkins_scm_trigger {
    local jenkins_config_file="$1"
    local cron_pattern="$2"

    sed -i '/<hudson.triggers.SCMTrigger>/{N; s/<spec>.*<\/spec>/<spec>'"$cron_pattern"'<\/spec>/g;s/<spec\/>/<spec>'"$cron_pattern"'<\/spec>/g}' "$jenkins_config_file"
}

function append_branch_to_newman_cron {
    local branch="$1"
    export SSHPASS=password
    sshpass -e ssh "$XAP_NEWMAN_USER"@"$XAP_NEWMAN_HOST" -C "sed -ri 's/crons.suitediff.branch = .*/crons.suitediff.branch = '$branch'/'g /home/xap/newman-analytics/resources/crons/suitediff/suitediff.properties"
}

function get_jenkins_job_config {
    local jenkins_job="$1"
    local jenkins_config_file="$2"
    #Get the current configuration and save it locally
    cmd="curl -X GET http://"$JENKINS_USER":"$JENKINS_PASSWORD"@"$JENKINS_HOST":"$JENKINS_PORT"/job/"$jenkins_job"/config.xml -o "$jenkins_config_file""
    eval "$cmd"
    local r="$?"
    if [ "$r" -ne 0 ]
    then
        echo "[ERROR] Failed to get jenkins config $jenkins_job, cmd: $cmd, exit code is: $r"
        exit "$r"
    fi
}

function post_jenkins_job_config {
    local jenkins_job="$1"
    local jenkins_config_file="$2"
    #Update the configuration via posting a local configuration file
    cmd="curl -X POST http://"$JENKINS_USER":"$JENKINS_PASSWORD"@"$JENKINS_HOST":"$JENKINS_PORT"/job/"$jenkins_job"/config.xml --data-binary "@"$jenkins_config_file"""
    eval "$cmd"
    local r="$?"
    if [ "$r" -ne 0 ]
    then
        echo "[ERROR] Failed to get jenkins config $jenkins_job, cmd: $cmd, exit code is: $r"
        exit "$r"
    fi
}

function increment_build_number {
    local jenkins_config_file="$1"
    local add="$2"

    local version_number=$(sed -n '/<name>XAP_BUILD_NUMBER<\/name>/{N; /.*/{N; /<defaultValue>.*<\/defaultValue>/p}}' "$jenkins_config_file" | grep defaultValue | sed -n '/defaultValue/{s/.*<defaultValue>\(.*\)<\/defaultValue>.*/\1/;p}')
    let "version_number = version_number + $add"
    sed -i '/<name>XAP_BUILD_NUMBER<\/name>/{N; /.*/{N; s/<defaultValue>.*<\/defaultValue>/<defaultValue>'$version_number'<\/defaultValue>/}}' "$jenkins_config_file"
}

function increment_milestone_number {
    local jenkins_config_file="$1"
    if [ "ga" == $NEXT_MILESTONE ]
    then
        sed -i '/<name>MILESTONE<\/name>/{N; /.*/{N; s/<defaultValue>.*<\/defaultValue>/<defaultValue>m'$NEXT_MILESTONE'<\/defaultValue>/}}' "$jenkins_config_file"
    else
        local milestone=$(sed -n '/<name>MILESTONE<\/name>/{N; /.*/{N; /<defaultValue>.*<\/defaultValue>/p}}' "$jenkins_config_file" | grep defaultValue | sed -n '/defaultValue/{s/.*<defaultValue>\(.*\)<\/defaultValue>.*/\1/;p}')
        milestone_number=${milestone:1:${#milestone}}
        ((milestone_number++))
        sed -i '/<name>MILESTONE<\/name>/{N; /.*/{N; s/<defaultValue>.*<\/defaultValue>/<defaultValue>m'$milestone_number'<\/defaultValue>/}}' "$jenkins_config_file"
    fi
}

function change_mode {
    local mode="$1"
    local jenkins_config_file="$2"
    sed -i '/<a class="string-array">/{N; s/<string>.*<\/string>/<string>'"$mode"'<\/string>/}' "$jenkins_config_file"
}

function change_branch {
    local branch="$1"
    local jenkins_config_file="$2"
    sed -i '/<name>BRANCH_NAME<\/name>/{N; /.*/{N; s/<defaultValue>.*<\/defaultValue>/<defaultValue>'"$branch"'<\/defaultValue>/}}' "$jenkins_config_file"
}

function change_tag {
    local tag="$1"
    local jenkins_config_file="$2"
    sed -i '/<name>TAG_NAME<\/name>/{N; /.*/{N; s/<defaultValue>.*<\/defaultValue>/<defaultValue>'"$tag"'<\/defaultValue>/}}' "$jenkins_config_file"
}

function create_release_branch {
    local git_folder="$1"
    local commit_sh="$2"

    (
	cd "$git_folder"

	if [ -z "$commit_sh" ]
	then
	    git checkout -b "$VERSION"-"$MILESTONE" master
	else
	    git checkout -b "$VERSION"-"$MILESTONE" "$commit_sh"
	fi
	git push --set-upstream origin "$VERSION"-"$MILESTONE"
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
        return 0;
    fi
    rm -rf "$folder"
    git clone "$url" "$folder"
}

# Get the folder from git url
# $1 is a git url of the form git@github.com:Gigaspaces/xap-premium.git
# The function will return a folder in the $WORKSPACE that match this git url (for example $WORKSPACE/xap-premium)
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

printenv


if [ "CLONE_REPOS_ONLY" == $THIS_SCRIPT_MODE ]; then
        clone_repos
    else
        if [ "RELEASE_XAP" == $THIS_SCRIPT_MODE ]; then
                clone_repos
                create_branches
                release_xap "$2"
        	else
        		if [ "BACK_TO_NIGHTLY_RELEASE_XAP" == $THIS_SCRIPT_MODE ]; then
                	back_to_nightly_release_xap
            	fi
        fi
fi
