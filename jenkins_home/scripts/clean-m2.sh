#!/bin/bash -x

if [ $# -eq 0 ]; then
    echo "No arguments provided, should be path to ./m2"
    exit 1
fi

rm -r $1//org/xap      
rm -r $1//org/gigaspaces 
rm -r $1/com/gigaspaces 
rm -r $1/org/openspaces 
rm -r $1/com/gs         
