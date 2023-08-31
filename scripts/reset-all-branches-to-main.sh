#!/bin/bash

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

# Checkout and update the main branch
git checkout main
git stash
git pull

# Delete local and remote branches and stashes that are not main
git branch | grep -v '^* main$' | xargs git branch -D
git fetch origin
git branch -r | grep -v '^  origin/main$' | sed 's/  origin\///' | xargs -I {} git push origin --delete {}

# Setup fresh branch code-development from main
git checkout -b code-development
git rm -r staging production scripts
find ./ -type f -name '*lock*' | xargs git rm
git commit -m "Setup code-development branch with only the development directory. [skip ci]"
git push -u --set-upstream origin code-development
git checkout main

# Setup fresh branch code-staging from main
git checkout -b code-staging
git rm -r development production scripts
find ./ -type f -name '*lock*' | xargs git rm
git commit -m "Setup code-staging branch with only the staging directory. [skip ci]"
git push -u --set-upstream origin code-staging
git checkout main

# Setup fresh branch code-production from main
git checkout -b code-production
git rm -r staging development scripts
find ./ -type f -name '*lock*' | xargs git rm
git commit -m "Setup code-production branch with only the production directory. [skip ci]"
git push -u --set-upstream origin code-production
git checkout main

# Clean up stashes
git stash clear

# Switch back to main branch
git checkout main
