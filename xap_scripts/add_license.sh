#!/bin/bash
################################
# AWK scripts                  #
################################
read -d '' scriptVariable << 'EOF'
BEGIN {
    package="^package .*"
    open_comment="/\\*"
    close_comment="\\*/"
    license="license"
    copyright="copyright"
    in_comment=0
}
{
     if (match($0, package)) {
        exit 0
     }
     if (match($0, open_comment)) {
        in_comment=1
     }
     if (match($0, close_comment)) {
        exit 0
     }
     if (match(tolower($0), license)) {
        if (in_comment == 1) {
 	    exit 1
        }
     }
     if (match(tolower($0), copyright)) {
        if (in_comment == 1) {
 	    exit 1
        }
     }
}
EOF

read -d '' license_header <<EOF
/*
 * Copyright (c) 2008-2016, GigaSpaces Technologies, Inc. All Rights Reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */


EOF
function has_license_header {
  local file="$1"
  awk "$scriptVariable" "$file"
  return $?
}

function add_license_header {
    has_license_header $1

    if [ "$?" -eq 0 ]
    then
	echo "$license_header" > tmp.txt
	cat "$1" >> tmp.txt
	rm -f "$1"
	mv tmp.txt "$1"
	echo "Adding license header to file: $1"
    fi
}

function scan_files {
    find $1 -name "*.java" -exec $0 "add" \{\} \;
}


if [ $# -eq 2 ]
then
    add_license_header $2
else
    scan_files $1
fi
