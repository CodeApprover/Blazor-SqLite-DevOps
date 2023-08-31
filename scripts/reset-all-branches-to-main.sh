#!/bin/bash

set -x

# WARNING message
echo "CAUTION:"
echo "This script will perform the following operations:"
echo "1. Checkout and update the main branch."
echo "2. DELETE all local and remote branches except 'main'."
echo "3. Create and setup fresh branches named 'code-development', 'code-staging', and 'code-production' based on 'main'."
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
branches=("code-production" "code-development" "code-staging")

# Delete local branches that are not main
for branch in "${branches[@]}"; do
  if git show-ref --quiet "refs/heads/$branch"; then
    git branch -D "$branch"
  fi
done

# Delete remote branches that are not main
remote_branches=("code-production" "code-development" "code-staging")
for remote_branch in "${remote_branches[@]}"; do
  if git show-ref --quiet "refs/remotes/origin/$remote_branch"; then
    git push origin --delete "$remote_branch"
  fi
done

# Set directories for branches
development=$(find . -type d -name "development")
staging=$(find . -type d -name "staging")
production=$(find . -type d -name "production")
scripts=$(find . -type d -name "scripts")

# Set up code-development
git checkout -b code-development main
git rm -r $production
git rm -r $staging
git rm $(find "$scripts" -type f -not -name 'execute-workflow.sh')
git commit -m "Setup new code-development branch. [skip ci]"
git push -u --set-upstream origin code-development
git checkout main

# Set up code-staging
git checkout -b code-staging main
git rm -r $production
git rm $(find "$scripts" -type f -not -name 'execute-workflow.sh')
git commit -m "Setup new code-staging branch. [skip ci]"
git push -u --set-upstream origin code-staging
git checkout main

# Set up code-production
git checkout -b code-development main
git rm -r $development
git rm $(find "$scripts" -type f -not -name 'execute-workflow.sh')
git commit -m "Setup new code-production branch. [skip ci]"
git push -u --set-upstream origin code-production

# Clean up stashes and switch back to main branch
git stash clear
git checkout main
