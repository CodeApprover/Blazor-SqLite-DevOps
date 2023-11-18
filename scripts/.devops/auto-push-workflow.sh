#!/bin/bash

# Set strict mode for script execution
set -o errexit
set -o nounset
set -o pipefail

# Variables from config (assumes config.json exists and jq is installed)
CONFIG_FILE="config.json"
BRANCHES=("code-development" "code-staging" "code-production")
PROJ_NAME=$(jq -r '.ProjectConfig.name' "$CONFIG_FILE")
MAX_PUSHES=$(jq -r '.MaxConfig.retries' "$CONFIG_FILE")
MAX_SECS_WAIT=$(jq -r '.MaxConfig.wait' "$CONFIG_FILE")

# Git operations
branch=$1
git checkout "$branch" || { echo "Git checkout error on $branch."; exit 1; }

# Loop for git add, commit, push
for (( i=1; i<=num_pushes; i++ )); do
  commit_msg="$(date +'%Y-%m-%d %H:%M:%S') - Automated push $i of $num_pushes"
  echo "Performing push $i of $num_pushes"
  
  # Add changes to git and commit
  git add -A || { echo "Git add error."; exit 1; }
  git commit -m "$commit_msg" || { echo "Git commit error."; exit 2; }
  git push || { echo "Git push error."; exit 1; }

  # Wait for specified interval
  if [ "$i" -lt "$num_pushes" ]; then
    sleep "$wait_seconds"
  fi
done

# Checkout main and return to the initial state
git checkout main || { echo "Git checkout error returning to main."; exit 3; }
