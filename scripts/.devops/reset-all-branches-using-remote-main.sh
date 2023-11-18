#!/bin/bash

# Check dependencies
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
if ! jq empty <<< "$JSON_CONFIG" &>/dev/null; then
  echo "Invalid JSON in config.json."
  exit 1
fi

# Extract constants from JSON
DEVOPS_USER=$(echo "$JSON_CONFIG" | jq -r '.DevOpsUser.name')
DEVOPS_EMAIL=$(echo "$JSON_CONFIG" | jq -r '.DevOpsUser.email')

# Extract branch names from JSON keys
mapfile -t BRANCHES < <(echo "$JSON_CONFIG" | jq -r '.Users | keys[]' | tr -d '\r')

# Set Git User
git config user.name "$DEVOPS_USER"
git config user.email "$DEVOPS_EMAIL"

# Stash changes and reset to remote main
git stash
git fetch origin
git reset --hard origin/main
git clean -fd

# Delete all local branches except main
for branch in $(git branch | grep -v "main"); do
  git branch -D "$branch"
done

# Delete all remote branches except main
for branch in "${BRANCHES[@]}"; do
  if git ls-remote --heads origin "$branch" | grep -q "$branch"; then
    git push origin --delete "$branch"
  fi
done

# Create and setup each code- branch
for branch in "${BRANCHES[@]}"; do
  git checkout -b "$branch"
  mkdir -p toolbox
  cp -r "scripts/${branch#code-}/"* toolbox/ || { echo "Failed to copy scripts to toolbox"; exit 1; }
  rm -rf scripts

  # Directory cleanup based on branch
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

  # Commit and push
  git add .
  git commit -m "Set up $branch branch"
  git push -u origin "$branch"
  git checkout main
done

# Drop all stashes
git stash clear
