# Scripts that can be used to release XAP

The main script is `scripts/release_xap.sh` it is self contained, the other scrips there only to support when something is not working and you wish to continue manually.
The configuration (should be passed as first parameter) is the name of a enviroment file that contains serios of bash exports that will be used in by the script. 

A sample configuration is in the file `scripts/setenv.sh`

First run is very slow because full git clone is done and maven m2 is empty.

After the first run it shoud take 20 min to release a new version.

## Running

From the `scripts` folder type `release_xap.sh setenv.sh`

## Configuration file explained

```bash
export BRANCH=xap-renaming-m3                     # The name of the source branch (where should we start from)
export VERSION=12.0.0-m7                          # The version that should be in the release poms.
export TAG_NAME="barak_$VERSION"                  # Once the maven install pass a tag is created and pushed for this source, this is the name of the tag.
export OVERRIDE_EXISTING_TAG=true                 # If equal to the string true, $TAG_NAME will be modified if already exists.
export DEPLOY_ARTIFACTS=true                      # If equal to true deply maven artifacts to s3 (provided that the setting in .m2 is configured)
export PERFORM_FULL_M2_CLEAN=true                 # If equal to true the directory $M2/repository will be deleted, otherwise only the xap part will be deleted,

export M2=/home/barakbo/tmp/m2                    # The location of the m2 maven, the script will delete some of the folder in this location it is best to use a dedicated folder for this script.
export WORKSPACE=/home/barakbo/tmp/workspace      # The location on the disk that the script will checkout the sources.

```

## Workflow description.

1. Clone xap-open and xap, this is done smartly to save time, indeed git **is** the information manager from hell.
2. Clean m2 from xap related directories.
3. Create temporary local git branch.
4. Rename poms.
5. Call maven install.
6. Commit changes.
7. Create tag.
8. Delete the temporary local branch.
9. Push the tag
10. Call maven deploy.

## How to run locally

First you will need to upload your public SSH keys to github, in case you don't have SSH keys you can generate pair using

```bash
	ssh-keygen -t rsa -b 4096 -C "your_email@example.com"
```

Next copy to the ring the output of `cat ~/.ssh/id_rsa.pub` and paset it your github account as descrbe in
https://help.github.com/articles/adding-a-new-ssh-key-to-your-github-account/

This will enable you to work with github from your machine using the git native protocol without need to authenticate.

Next clone this git repo, modify the `setenv.sh` file you can have the `M2` and `WORKSPACE` vars pointing each to an empty folder
and run with `./release_xap.sh setenv.sh`


## Comparing release_xap.sh with maven release plugin

feature | release_xap.sh | maven release plugin | remarks
--- | --- | --- | ---
Standard | :x: | :white_check_mark: |
Well debugged | :x: | :white_check_mark: |
Can run from console | :white_check_mark: | :white_check_mark: |
Fast | :white_check_mark: | :x: | ~20 min vs ~2 hour
Play well with multiple repositories | :white_check_mark: | :x: |
Fail fast | :white_check_mark: | :x: | when OVERRIDE_EXISTING_TAG is not set to true release_.xap.sh will not start the build if the tag exist in local or remote repository
Clear error messages | :white_check_mark: | :x: | 
Can run partually | :white_check_mark: | :x: | from console by commenting lines in the script
Debuggable | :white_check_mark: | :x: | just add `-x` in the top
Can be customized | :white_check_mark: | :x: | very easy to add a new envoriment variable and to use its value from the script.
Simplicity | :white_check_mark: | :x: | script  < 250 lines against > 10000 lines of Jave lines and many external dependencies.
Loved by it's comunity | :white_check_mark: | :x:  | 


