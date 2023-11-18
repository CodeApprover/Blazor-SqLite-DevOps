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

# Update main branch
git checkout main
git pull origin main
git fetch origin
git reset --hard origin/main

# Process each code- branch
for branch in "${BRANCHES[@]}"; do
  echo "Processing branch: $branch"

  # Delete local branch if exists
  if git rev-parse --verify "$branch" > /dev/null 2>&1; then
    git branch -D "$branch"
  fi

  # Delete remote branch if exists
  if git ls-remote --heads origin "$branch" | grep -q "$branch"; then
    git push origin --delete "$branch"
  fi

  # Create new branch from main
  git checkout -b "$branch"
  mkdir -p toolbox
  script_dir="scripts/${branch#code-}"
  
  # Copy scripts and remove scripts directory
  if [[ -d "$script_dir" ]]; then
    cp -r "$script_dir/"* toolbox/ || { echo "Failed to copy from $script_dir to toolbox"; exit 1; }
    git add toolbox/*
  else
    echo "Directory $script_dir does not exist or is empty."
  fi
  rm -rf scripts

  # Branch-specific directory cleanup
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

  # Commit and push changes
  if ! git diff --quiet; then
    git add .
    git commit -m "Updated $branch from main"
    git push -u origin "$branch"
  else
    echo "No changes to commit for $branch."
  fi

  # Return to main branch
  git checkout main
done

# Drop all stashes
git stash clear
