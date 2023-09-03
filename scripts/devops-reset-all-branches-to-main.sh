#!/bin/bash

# find . -name "*.sh" -exec dos2unix {} \; -exec sed -i 's/^[ \t]*$//' {} \;

# Ensure this script is executed from the scripts directory
current_dir=$(pwd)
if [[ "$current_dir" != *"/scripts" ]]; then
    echo "Error: Please execute this script from the 'scripts' directory." && exit 70
fi

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
    echo "Exiting without making changes." && exit 11
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

# Find the development directory
development=$(find ../ -type d -name "development" | head -n 1)

# If the development directory is found
if [[ -n "$development" ]]; then
    # Extract the parent directory of the development directory
    parent_dir=$(dirname "$development")

    # Use the parent directory to locate the other directories
    production="$parent_dir/production"
    staging="$parent_dir/staging"
    scripts="$parent_dir/scripts"

    # Check if the directories exist
    ! [[ -d "$production" ]] && echo "Production directory not found at: $production" && exit 12
    ! [[ -d "$staging" ]] && echo "Staging directory not found at: $staging" && exit 13
    ! [[ -d "$scripts" ]] && echo "Scripts directory not found at: $scripts" && exit 14
else
    ls -la ../
    echo "Development directory not found." && exit 15
fi

# Find Files to remove for branches:
files_to_remove_dev=$(find "$scripts" -type f -name "*.sh" | grep -v '-development-')
files_to_remove_staging=$(find "$scripts" -type f -name "*.sh" | grep -v '-staging-')
files_to_remove_production=$(find "$scripts" -type f -name "*.sh" | grep -v '-production-')

# Set up code-development
git checkout -b code-development main
git rm -r "$production"
git rm -r "$staging"
for file in $files_to_remove_dev; do git rm "$file"; done
git commit -m "Setup new code-development branch. [skip ci]"
git push -u --set-upstream origin code-development
git checkout main

# Set up code-staging
git checkout -b code-staging main
git rm -r "$production"
for file in $files_to_remove_staging; do git rm "$file"; done
git commit -m "Setup new code-staging branch. [skip ci]"
git push -u --set-upstream origin code-staging
git checkout main

# Set up code-production
git checkout -b code-production main
git rm -r "$development"
for file in $files_to_remove_production; do git rm "$file"; done
git commit -m "Setup new code-production branch. [skip ci]"
git push -u --set-upstream origin code-production

# Clean up stashes and switch back to main branch
git stash clear
git checkout main
