#!/bin/bash

# Install
kind create cluster --config .devcontainer/kind-cluster.yml --wait 300s
chmod +x .devcontainer/deployment.sh && .devcontainer/deployment.sh