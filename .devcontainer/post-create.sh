#!/bin/bash

# Install
kind create cluster --config .devcontainer/kind-cluster.yml --wait 300s
chmod +x .devcontainer/deployment.sh && .devcontainer/deployment.sh

# Creation Ping
curl -X POST https://grzxx1q7wd.execute-api.us-east-1.amazonaws.com/default/codespace-tracker \
  -H "Content-Type: application/json" \
  -d "{
    \"tenant\": \"$DT_ENDPOINT\",
    \"repo\": \"$GITHUB_REPOSITORY\",
    \"demo\": \"obslab-syslog\",
    \"codespace.name\": \"$CODESPACE_NAME\"
  }"
