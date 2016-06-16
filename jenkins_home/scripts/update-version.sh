#!/bin/bash

version="$(grep -m1 '<version>' pom.xml | sed 's/<version>\(.*\)<\/version>/\1/')"
trimmed_version="$(echo -e "${version}" | tr -d '[[:space:]]')"
find . -name "pom.xml" -exec sed -i.bak "s/$trimmed_version/$1/" \{\} \;

