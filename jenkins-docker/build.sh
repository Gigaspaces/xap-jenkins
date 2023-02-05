#!/usr/bin/env bash
docker build --build-arg STORAGE_SERVER=${STORAGE_SERVER=gs-storage-server.s3.amazonaws.com} -t xap/jenkins .
