#!/usr/bin/env bash
docker build --build-arg STORAGE_SERVER=${STORAGE_SERVER=imc-srv01} -t xap/jenkins .
