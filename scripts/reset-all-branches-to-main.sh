#!/bin/bash

set -x

# WARNING message
echo "CAUTION:"
echo "This script will perform the following operations:"
echo "1. Checkout and update the main branch."
echo "2. DELETE all local and remote branches except 'main'."
echo "3. Create and setup fresh branches named 'code-development', 'code-staging' and 'code-production' based on 'main'."
echo ""
echo "Consequences:"
echo "- Any unmerged changes in deleted branches will be LOST FOREVER."
echo "- The deleted branches on the remote could impact other collaborators' work."
echo "- The operations are irreversible. Ensure you have a backup if needed."
echo "- All stashes will be dropped and lost."
echo ""
read -p "Do you wish to proceed? (y/n): " -r

# Check for the user's response
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    echo "Exiting without making changes."
    exit 1
fi

# Configure git user
git config user.name "CodeApprover"
git config user.email "pucfada@pm.me"

# Checkout and update the main branch
git checkout main
git stash
git pull

# Set branch names
branches=("code-development" "code-staging" "code-production")

# Delete local branches
for branch in "${branches[@]}"; do
  if git show-ref --quiet "refs/heads/$branch"; then
    git branch -D "$branch"
  fi
done

# Delete remote branches
for remote_branch in "${branches[@]}"; do
  if git show-ref --quiet "refs/remotes/origin/$remote_branch"; then
    git push origin --delete "$remote_branch"
  fi
done

# Set directories for branches
development=$(find ../ -type d -name "development")
staging=$(find ../ -type d -name "staging")
production=$(find ../ -type d -name "production")

# Check if directories were found, exit if not
if [[ -z "$development" || -z "$staging" || -z "$production" || -z "$scripts" ]]; then
    echo "Required directories not found. Exiting."
    ls -la ../
    exit 10
fi

# Find all files in the scripts directory except execute-workflow.sh
scripts=$(find ../ -type d -name "scripts")
files_to_remove=$(find "$scripts" -type f ! -name 'execute-workflow.sh')

# Check if restricted script files exist, exit if not
if [[ -z "$files_to_remove" ]]; then
    echo "Required script files not found. Exiting."
    ls -la "$scripts"
    exit 11
fi

# Set up code-development
git checkout -b code-development main
git rm -r "$production"
git rm -r "$staging"
git rm "$files_to_remove"
git commit -m "Setup new code-development branch. [skip ci]"
git push -u --set-upstream origin code-development
git checkout main

# Set up code-staging
git checkout -b code-staging main
git rm -r "$production"
git rm "$files_to_remove"
git commit -m "Setup new code-staging branch. [skip ci]"
git push -u --set-upstream origin code-staging
git checkout main

# Set up code-production
git checkout -b code-production main
git rm -r "$development"
git rm "$files_to_remove"
git commit -m "Setup new code-production branch. [skip ci]"
git push -u --set-upstream origin code-production

# Clean up stashes and switch back to main branch
git stash clear
git checkout main
