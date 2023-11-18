#!/bin/bash

# Script Description: Resets local main to remote main and updates specific branches.

# Check if JQ is installed
if ! command -v jq &> /dev/null; then
  echo "jq is not installed."
  exit 1
fi

# Check if the JSON file exists
if [[ ! -e "config.json" ]]; then
  echo "config.json does not exist."
  exit 1
fi

# Load the JSON config
JSON_CONFIG=$(cat config.json)

# Ensure JSON is valid
if ! jq empty <<< "$JSON_CONFIG" &>/dev/null; then
  echo "Invalid JSON in config.json."
  exit 1
fi

# Extract constants from json
DEVOPS_USER=$(echo "$JSON_CONFIG" | jq -r '.DevOpsUser.name')
DEVOPS_EMAIL=$(echo "$JSON_CONFIG" | jq -r '.DevOpsUser.email')
EXPECTED_DIR=$(echo "$JSON_CONFIG" | jq -r '.ProjectConfig.dir')

# Extract branch names from json keys
mapfile -t BRANCHES < <(echo "$JSON_CONFIG" | jq -r '.Users | keys[]' | tr -d '\r')

# Ensure correct directory
CUR_DIR="$(dirname "$0")"
cd "$CUR_DIR" || exit 1

# Set Git User
git config user.name "$DEVOPS_USER"
git config user.email "$DEVOPS_EMAIL"

# Checkout main branch and update it
git checkout main
git pull origin main

# Reset local main branch to mirror remote main
git fetch origin
git reset --hard origin/main

# Process each code- branch as required
for branch in "${BRANCHES[@]}"; do
  # Delete local branch if exists
  git branch | grep -q "$branch" && git branch -D "$branch"

  # Delete remote branch if exists
  git ls-remote --heads origin "$branch" | grep -q "$branch" && git push origin --delete "$branch"

  # Create a new branch from main and switch to it
  git checkout -b "$branch"

  # Perform branch-specific directory cleanup
  case "$branch" in
    "${BRANCHES[0]}") # code-development
      rm -rf staging production
      ;;
    "${BRANCHES[1]}") # code-production
      rm -rf development
      ;;
    "${BRANCHES[2]}") # code-staging
      rm -rf production
      ;;
  esac

  # Push new branch to remote
  git add .
  git commit -m "Updated $branch from main"
  git push -u origin "$branch"
done

# Return to the main branch
git checkout main

# Drop all stashes
git stash clear
