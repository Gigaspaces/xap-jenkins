#!/bin/bash -x

if [ $# -eq 0 ]; then
    echo "No arguments provided, should be path to ./m2"
    exit 1
fi

rm -rf $1/org/xap      
rm -rf $1/org/gigaspaces 
rm -rf $1/com/gigaspaces 
rm -rf $1/org/openspaces 
rm -rf $1/com/gs         
