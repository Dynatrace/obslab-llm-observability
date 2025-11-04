#!/bin/bash

# Set repo path so core functionality can be loaded and RepositoryName
export REPO_PATH="$(pwd)"
export RepositoryName=$(basename "$REPO_PATH")

if [ -f "$REPO_PATH/.devcontainer/util/functions.sh" ]; then
  source "$REPO_PATH/.devcontainer/util/functions.sh"
  printInfo "dt-enablement functions loaded"
else
  echo "⚠️ File not found: $REPO_PATH/.devcontainer/util/functions.sh"
  echo "to load the framework do 'source .devcontainer/util/source_framework.sh'"
fi