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

# Rename all version of each pom in $1 folder with $VERSION
function rename_poms {
    # Find current version from the pom.xml file in $1 folder.
    local version="$(grep -m1 '<version>' $1/pom.xml | sed 's/<version>\(.*\)<\/version>/\1/')"
    # Since grep return the whole line there are spaces that needed to trim.
    local trimmed_version="$(echo -e "${version}" | tr -d '[[:space:]]')"
    # Find each pom.xml under $1 and replace every $trimmed_version with $VERSION
    find "$1" -name "pom.xml" -exec sed -i.bak "s/$trimmed_version/$VERSION/" \{\} \;
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
    if [ "PERFORM_FULL_M2_CLEAN" = "true" ]
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
    pushd "$1"
    cmd="mvn -Dmaven.repo.local=$M2/repository -DskipTests install"
    eval "$cmd"
    local r="$?"
    popd
    if [ "$r" -ne 0 ]
    then
        times
        echo "[ERROR] Failed While installing using maven in folder: $1, command is: $cmd, exit code is: $r"
        exit "$r"
    fi
}

# Call maven deploy from directory $1
# It uses the target deploy:deploy to bypass the build.
# In case of none zero exit code exit code stop the release
function mvn_deploy {

    pushd "$1"
    cmd="mvn -Dmaven.repo.local=$M2/repository -DskipTests deploy:deploy"
    eval "$cmd"
    local r="$?"
    popd
    if [ "$r" -ne 0 ]
    then
        times
        echo "[ERROR] Failed While installing using maven in folder: $1, command is: $cmd, exit code is: $r"
        exit "$r"
    fi

}

# Commit local changes and create a tag in dir $1.
# It assume the branch is the local temp branch,
function commit_changes {
    local folder="$1"
    local msg="Modify poms to $VERSION in temp branch that was built on top of $BRANCH"

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
        times
        echo "[ERROR] Tag $TAG_NAME already exists in repository $folder, you can set OVERRIDE_EXISTING_TAG=\"true\" to override this tag"
        exit "$r"
    fi
    popd
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
function release_xap {

    local xap_open_url="git@github.com:Gigaspaces/xap-open.git"
    local xap_url="git@github.com:Gigaspaces/xap.git"
    local temp_branch_name="$BRANCH-$VERSION"    
    local xap_open_folder="$(get_folder $xap_open_url)"
    local xap_folder="$(get_folder $xap_url)"
    echo "xap_folder is $xap_folder"

    clone "$xap_open_url" 
    clone "$xap_url"

    if [ "$OVERRIDE_EXISTING_TAG" != "true" ] 
    then
	exit_if_tag_exists "$xap_open_folder" 
	exit_if_tag_exists "$xap_folder" 
    fi


    clean_m2 

    create_temp_branch "$temp_branch_name" "$xap_open_folder"
    create_temp_branch "$temp_branch_name" "$xap_folder"

    rename_poms "$xap_open_folder"
    rename_poms "$xap_folder"

    
    mvn_install "$xap_open_folder"
    echo "Done installing xap open"
    times

    mvn_install "$xap_folder"
    echo "Done installing xap"
    times
    
    commit_changes "$xap_open_folder" 
    commit_changes "$xap_folder"

    delete_temp_branch "$xap_open_folder" "$temp_branch_name"
    delete_temp_branch "$xap_folder" "$temp_branch_name"
    
    if [ "$DEPLOY_ARTIFACTS" = "true" ]
    then
	mvn_deploy "$xap_open_folder"
	mvn_deploy "$xap_folder"
    fi
	times
	echo "DONE."
}


release_xap 



