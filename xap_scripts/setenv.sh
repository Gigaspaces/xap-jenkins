export BRANCH=xap-renaming-m3                       # The name of the source branch (where should we start from)
export VERSION=12.0.0-m13                           # The version that should be in the release poms.
export TAG_NAME="barak_$VERSION"                    # Once the maven install pass a tag is created and pushed for this source, this is the name of the tag.
export OVERRIDE_EXISTING_TAG=true                   # If equal to the string true, $TAG_NAME will be modified if already exists.
export DEPLOY_ARTIFACTS=true                       # If equal to true deply maven artifacts to s3 (provided that the setting in .m2 is configured).
#export PERFORM_FULL_M2_CLEAN=true                  # If equal to true the directory $M2/repository will be deleted, otherwise only the xap part will be deleted.

export M2=/home/barakbo/tmp/m2                      # The location of the m2 maven, the script will delete some of the folder in this location it is best to use a dedicated folder for this script.
export WORKSPACE=/home/barakbo/tmp/workspace        # The location on the disk that the script will checkout the sources.

