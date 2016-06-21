#!/bin/bash

if [ $# -ne 1 ]; then
    echo "Usage: $0 setenv.sh"
    exit 1
fi

source "$1"


# Get the folder from git url 
# $1 is a git url of the form git@github.com:Gigaspaces/xap-open.git
# The function will return a folder in the $WORKSPACE that match this git url (for example $WORKSPACE/xap-open)
function get_folder {
    echo -n "$WORKSPACE/$(echo -e $1 | sed 's/.*\/\(.*\)\.git/\1/')"
}

# Try to checkout the branch $BRANCH in the git folder $1
# Discard all local commits and local modifications, calling this function will loose all local commits and local changes.
# It will remove any untracked file as well.
# It return nonezero status in case of error, to signal that new clone is needed.
function checkout_branch {
    local folder="$1"
    (
	cd "$folder"
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
            exit "$r"
        fi
	git rebase --no-stat
	return "$?"
    ) 
}

# Try to checkout branch $BRANCH in git folder $1.
# In case of failuer delete folder $1 and use fresh clone to create this folder.
function clone {
    local url="$1"
    local folder="$(get_folder $1)"
    
    if [ -d "$folder" ]
    then
        checkout_branch "$folder" "$branch"
        if [ $? -eq 0 ]
        then
    	    return 0;
        fi
    fi
    rm -rf "$folder"
    git clone "$url" "$folder" 
    checkout_branch "$folder"
}

# Rename all version of each pom in $1 folder with $RELEASE_VERSION
function rename_poms {
    # Find current version from the pom.xml file in $1 folder.
    local version="$(grep -m1 '<version>' $1/pom.xml | sed 's/<version>\(.*\)<\/version>/\1/')"
    # Since grep return the whole line there are spaces that needed to trim.
    local trimmed_version="$(echo -e "${version}" | tr -d '[[:space:]]')"
    # Find each pom.xml under $1 and replace every $trimmed_version with $VERSION
    find "$1" -name "pom.xml" -exec sed -i.bak "s/$trimmed_version/$RELEASE_VERSION/" \{\} \;
}

# Create a temporary branch for the pom changes commits.
# If such branch already exists delete it (is it wise ?)
# Do not push this branch.
function create_temp_branch {
    local temp_branch_name="$1"
    local git_folder="$2"
    (
	cd "$git_folder"
	git checkout "$BRANCH"
	git show-ref --verify --quiet "refs/heads/$temp_branch_name"
	if [ "$?" -eq 0 ]
	then
	    git branch -D  "$temp_branch_name"
	fi
	git checkout -b "$temp_branch_name"
    )
}

#
function clean_m2 {
    if [ "$PERFORM_FULL_M2_CLEAN" = "true" ]
    then
	rm -rf $M2/repository
    else
	rm -rf $M2/repository/org/xap      
	rm -rf $M2/repository/org/gigaspaces 
	rm -rf $M2/repository/com/gigaspaces 
	rm -rf $M2/repository/org/openspaces 
	rm -rf $M2/repository/com/gs         
    fi
}

# Call maven install from directory $1
# In case of none zero exit code exit code stop the release
function mvn_install {
    local rep="$2"
    pushd "$1"
    #cmd="mvn -B -Dmaven.repo.local=$M2/repository -DskipTests install"
    local GIT_SHA=`git rev-parse HEAD`
    local SHA_PROP="-Dgs.buildshapremium"    
    if [ "$repo" == "OPEN" ]; then
	SHA_PROP="-Dgs.buildsha"
	cmd="mvn -B -P release-zip -Dmaven.repo.local=$M2/repository -DskipTests install javadoc:jar -Dgs.version=${XAP_VERSION} -Dgs.milestone=${MILESTONE} -Dgs.buildnumber=${BUILD_NUMBER} ${SHA_PROP}=${GIT_SHA}"
    else
	cmd="mvn -B -P extract-xap-open-folder -Dmaven.repo.local=$M2/repository -DskipTests install -P aggregate-javadoc -Dgs.version=${XAP_VERSION} -Dgs.milestone=${MILESTONE} -Dgs.buildnumber=${BUILD_NUMBER} ${SHA_PROP}=${GIT_SHA}"
    fi
    echo "****************************************************************************************************"
    echo "Installing $rep"
    echo "Executing cmd: $cmd"
    echo "****************************************************************************************************"
    eval "$cmd"
    local r="$?"
    popd
    if [ "$r" -ne 0 ]
    then
        echo "[ERROR] Failed While installing using maven in folder: $1, command is: $cmd, exit code is: $r"
        exit "$r"
    fi
}



function publish_to_newman {
    pushd "$1"
    cmd="mvn -B -Dmaven.repo.local=$M2/repository -o -pl xap-dist process-sources -P generate-zip -P copy-artifact-and-submit-to-newman -P extract-xap-open-folder -Dgs.version=${XAP_VERSION} -Dgs.milestone=${MILESTONE} -Dgs.buildnumber=${BUILD_NUMBER} -Dgs.branch=${BRANCH} -Dnewman.tags=${NEWMAN_TAGS}"
    echo "****************************************************************************************************"
    echo "Publish to newman"
    echo "Executing cmd: $cmd"
    echo "****************************************************************************************************"
    eval "$cmd"
    local r="$?"
    popd
    if [ "$r" -ne 0 ]
    then
        echo "[ERROR] Failed While publishing to newman: $1, command is: $cmd, exit code is: $r"
        exit "$r"
    fi
}


# Call maven deploy from directory $1
# It uses the target deploy:deploy to bypass the build.
# In case of none zero exit code exit code stop the release
function mvn_deploy {

    pushd "$1"
    cmd="mvn -B -Dmaven.repo.local=$M2/repository javadoc:jar -DskipTests deploy"
    echo "****************************************************************************************************"
    echo "Maven deploy"
    echo "Executing cmd: $cmd"
    echo "****************************************************************************************************"
    eval "$cmd"
    local r="$?"
    popd
    if [ "$r" -ne 0 ]
    then
        echo "[ERROR] Failed While installing using maven in folder: $1, command is: $cmd, exit code is: $r"
        exit "$r"
    fi

}

# Commit local changes and create a tag in dir $1.
# It assume the branch is the local temp branch,
function commit_changes {
    local folder="$1"
    local msg="Modify poms to $RELEASE_VERSION in temp branch that was built on top of $BRANCH"

    pushd "$folder"
    git add -u
    git commit -m "$msg"
    git tag -f -a "$TAG_NAME" -m "$msg"
    popd
}

# Delete the temp branch $2 in folder $1
# Push the tag to origin
function delete_temp_branch {
    local folder="$1"
    local temp_branch="$2"

    pushd "$folder"

    git checkout -q "$TAG_NAME"
    git branch -D "$temp_branch"
    
    if [ "$OVERRIDE_EXISTING_TAG" != "true" ] 
    then
	git push origin "$TAG_NAME"
    else
	git push -f origin "$TAG_NAME"
    fi    

    popd
}

function exit_if_tag_exists {
    local folder="$1"
    
    pushd "$folder"
    git show-ref --verify --quiet "refs/tags/$TAG_NAME"
    local r="$?"
    if [ "$r" -eq 0 ]
    then
        echo "[ERROR] Tag $TAG_NAME already exists in repository $folder, you can set OVERRIDE_EXISTING_TAG=true to override this tag"
        exit 1
    fi
    popd
}

function upload_zip {
    echo "uploading zip $1 $2"
    local folder="$1"
    pushd "$folder"
    if [ "$2" == "xap" ]
    then
        cmd="mvn -Dmaven.repo.local=$M2/repository com.gigaspaces:xap-build-plugin:deploy-native -Dput.source=xap-dist/target/gigaspaces-xap-premium-$XAP_VERSION-$MILESTONE-b$FINAL_BUILD_NUMBER.zip -Dput.target=com/gigaspaces/xap/$XAP_VERSION/$FINAL_VERSION"
    else
        cmd="mvn -Dmaven.repo.local=$M2/repository com.gigaspaces:xap-build-plugin:deploy-native -Dput.source=xap-dist/target/gigaspaces-xap-open-$XAP_VERSION-$MILESTONE-b$FINAL_BUILD_NUMBER.zip -Dput.target=com/gigaspaces/xap-open/$XAP_VERSION/$FINAL_VERSION"
    fi
    echo "****************************************************************************************************"
    echo "uploading $2 zip"
    echo "Executing cmd: $cmd"
    echo "****************************************************************************************************"
    eval "$cmd"
    local r="$?"
    if [ "$r" -eq 1 ]
    then
        echo "[ERROR] failed to upload $2 zip, exit code:$r"
    fi
    popd
}

function upload_docs {
    echo "uploading docs $2"
    local folder="$1"
    pushd "$folder"

    cmd="mvn -Dmaven.repo.local=$M2/repository com.gigaspaces:xap-build-plugin:deploy-native -Dput.source=xap-dist/target/package/docs/xap-javadoc.jar -Dput.target=com/gigaspaces/xap/$XAP_VERSION/$FINAL_VERSION"

    echo "****************************************************************************************************"
    echo "uploading $2 javadoc"
    echo "Executing cmd: $cmd"
    echo "****************************************************************************************************"
    eval "$cmd"
    local r="$?"
    if [ "$r" -eq 1 ]
    then
        echo "[ERROR] failed to upload $2 javadoc, exit code:$r"
    fi
    popd
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

# Clone xap-open and xap.
# Clean m2 from xap related directories.
# Create temporary local git branch.
# Rename poms.
# Call maven install.
# Commit changes.
# Create tag.
# Delete the temporary local branch.
# Push the tag
# Call maven deploy.
# upload zip to s3.
function release_xap {

    local xap_open_url="git@github.com:Gigaspaces/xap-open.git"
    local xap_url="git@github.com:Gigaspaces/xap.git"
    local temp_branch_name="$BRANCH-$RELEASE_VERSION"    
    local xap_open_folder="$(get_folder $xap_open_url)"
    local xap_folder="$(get_folder $xap_url)"
    

    announce_step "clone xap-open"
    clone "$xap_open_url" 
    announce_step "clone xap"
    clone "$xap_url"

    if [ "$OVERRIDE_EXISTING_TAG" != "true" ] 
    then
        announce_step "delete tag $TAG in xap open"
	exit_if_tag_exists "$xap_open_folder" 
        announce_step "delete tag $TAG in xap"
	exit_if_tag_exists "$xap_folder" 
    fi

    announce_step "clean m2"
    clean_m2 

    announce_step "create temporary local branch $temp_branch_name in xap open"
    create_temp_branch "$temp_branch_name" "$xap_open_folder"
    announce_step "create temporary local branch $temp_branch_name in xap"
    create_temp_branch "$temp_branch_name" "$xap_folder"

    announce_step "rename poms in xap open"
    rename_poms "$xap_open_folder"
    announce_step "rename poms in xap"
    rename_poms "$xap_folder"

    
    announce_step "executing maven install on xap-open"
    mvn_install "$xap_open_folder" "OPEN"
    echo "Done installing xap open"


    announce_step "executing maven install on xap"
    mvn_install "$xap_folder" "CLOSED"
    echo "Done installing xap"

    
    announce_step "commiting changes in xap open"
    commit_changes "$xap_open_folder" 
    announce_step "commiting changes in xap"
    commit_changes "$xap_folder"

    announce_step "delete temp branch $temp_branch_name in xap open"
    delete_temp_branch "$xap_open_folder" "$temp_branch_name"
    announce_step "delete temp branch $temp_branch_name in xap"
    delete_temp_branch "$xap_folder" "$temp_branch_name"

    announce_step "publish to newman"
    publish_to_newman "$xap_folder"
    echo "Done publishing to newman"

    
    if [ "$DEPLOY_ARTIFACTS" = "true" ]
    then
	announce_step "deploying xap open"
	mvn_deploy "$xap_open_folder" 
	announce_step "deploying xap"
	mvn_deploy "$xap_folder"

	announce_step "uploading xap open zip"
	upload_zip "$xap_folder" "xap-open"
	announce_step "uploading xap zip"
	upload_zip "$xap_folder" "xap"
	announce_step "uploading xap docs"
	upload_docs "$xap_folder" "xap"
    fi
    echo "DONE."
}


release_xap
