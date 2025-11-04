#!/bin/bash
# Load framework
source .devcontainer/util/source_framework.sh

printInfoSection "Running integration Tests for $RepositoryName"

assertRunningPod ai-travel-advisor ollama

assertRunningPod ai-travel-advisor weaviate

assertRunningPod ai-travel-advisor ai-travel-advisor

assertRunningApp 30100

