#!/bin/bash

if [ $# -eq 2 ]; then
    version="$(grep -m1 '<version>' pom.xml | sed 's/<version>\(.*\)<\/version>/\1/')"
    trimmed_version="$(echo -e "${version}" | tr -d '[[:space:]]')"
    find $1 -name "pom.xml" -exec sed -i.bak "s/$trimmed_version/$2/" \{\} \;
else
    echo "Usage: $0 working-folder maven-version"
    exit 1
fi

