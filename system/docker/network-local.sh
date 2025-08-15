#!/bin/bash


docker network create -d bridge --gateway "172.18.0.1" --subnet "172.18.0.0/16" "local"

