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

# Configure git user
git config user.name "CodeApprover"
git config user.email "pucfada@pm.me"

# Checkout and update the main branch
git checkout main
git stash
git pull

# Delete local and remote branches and stashes that are not main
git branch | grep -v '^* main$' | xargs git branch -D
git fetch origin
git branch -r | grep -v '^  origin/main$' | sed 's/  origin\///' | xargs -I {} git push origin --delete {}

# Function to set up a fresh branch
set_branch() {
    local branch_name=$1
    local path_to_delete=$2
    git checkout -b $branch_name
    git checkout main -- $path_to_delete
    git rm -r $path_to_delete
    git rm $(find . -type f -name "execute-workflow.sh")
    git commit -m "Setup $branch_name branch with only the relevant directory. [skip ci]"
    git push -u --set-upstream origin $branch_name
    git checkout main
}

# Trim file lists for branches
set_branch code-production $(find . -type d -name "development")
set_branch code-staging $(find . -type d -name "production")
set_branch code-development $(find . -type d -name "staging") $(find . -type d -name "production")

# Clean up stashes
git stash clear

# Switch back to main branch
git checkout main
