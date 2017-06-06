#!/bin/bash
set -x
# if [ $# -ne 1 ]; then
#     echo "Usage: $0 ie-release-params.sh"
#     exit 1
# fi

# source "$1"



# Get the folder from git url 
# $1 is a git url of the form git@github.com:InsightEdge/insightedge.git
# The function will return a folder in the $WORKSPACE that match this git url (for example $WORKSPACE/insightedge)
function get_folder {
    echo -n "$WORKSPACE/$(echo -e $1 | sed 's/.*\/\(.*\)\.git/\1/')"
}

# Try to checkout the branch $BRANCH in the git folder $1
# Discard all local commits and local modifications, calling this function will loose all local commits and local changes.
# It will remove any untracked file as well.
# It return nonezero status in case of error, to signal that new clone is needed.
function checkout_branch {
    local folder="$1"
    pushd "$folder"
    git reset --hard HEAD
    git checkout -- .
    git clean -d -x --force --quiet .
    git gc --auto
    # Delete all local tags since git fetch --tags --prune does not realy prune tags.
    git tag -l | xargs git tag -d &> /dev/null   
    # Fetch all branch and tags from remote, prune tags that was deleted on the remote repository.
    git fetch --tags --prune --quiet 
    git checkout "$BRANCH"
    local r="$?"
    if [ "$r" -ne 0 ]
    then
        echo "[ERROR] Failed While checking out branch: $BRANCH, exit code is: $r"
        popd
        return 2
    fi
    git rebase --no-stat
    popd
    return 0
}

# Try to checkout branch $BRANCH in git folder $1.
# In case of failuer delete folder $1 and use fresh clone to create this folder.
function clone {
    local url="$1"
    local folder="$(get_folder $1)"
    
    if [ -d "$folder" ]
    then
        checkout_branch "$folder" "$branch"
        local r=$?
        if [ $r -eq 0 ]
        then
    	    return 0;
    	elif [ $r -eq 2 ]
        then
            exit 1
        fi
    fi
    rm -rf "$folder"
    git clone "$url" "$folder" 
    checkout_branch "$folder"
    if [ $? -ne 0 ]
    then
        exit 1;
    fi
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


# Clone InsightEdge,InsightEdge-examples,InsightEdge-zeppelin
function clone_ie {

    local ie_url="git@github.com:InsightEdge/insightedge.git"
    local ie_examples_url="git@github.com:InsightEdge/insightedge-examples.git"
    local ie_zeppelin_url="git@github.com:InsightEdge/insightedge-zeppelin.git"


    announce_step "clone ie"
    clone "$ie_url"

    announce_step "clone ie examples"
    clone "$ie_examples_url"


    announce_step "clone ie zeppelin"
    clone "$ie_zeppelin_url"



    announce_step "IE Clone DONE !"

}

clone_ie

