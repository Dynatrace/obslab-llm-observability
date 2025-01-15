#!/bin/zsh

podman manifest rm travel-advisor
podman manifest create travel-advisor

podman build -t thisthatdc/travel-advisor:v0.2.2 --platform=linux/amd64,linux/arm64 --manifest localhost/travel-advisor .
podman manifest push travel-advisor docker://docker.io/thisthatdc/travel-advisor:v0.2.2
