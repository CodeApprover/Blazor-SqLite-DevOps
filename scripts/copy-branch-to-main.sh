#!/bin/bash

# Array of available options
available_options=("code-development" "code-staging" "code-production")

# Check if no argument is provided
if [ $# -ne 1 ]; then
    echo "Usage: $0 <branch>"
    echo "Available options: ${available_options[*]}"
    exit 1
fi

branch=$1

# Check if the provided branch option is valid
if [[ ! " ${available_options[*]} " =~ " $branch " ]]; then
    echo "Error: Invalid branch option. Available options are: ${available_options[*]}"
    exit 1
fi

# WARNING message
echo "CAUTION:"
echo "This script will perform the following operations:"
echo "1. Checkout and update the main branch."
echo "2. Overwrite the '$branch' branch ${branch#code-} directory in 'main' branch."
echo ""
echo "Consequences:"
echo "- The '$branch' directory will be copied to 'main' branch."
echo ""
read -p "Do you wish to proceed? (y/n): " -r

# Check for the user's response
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
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

# Copy the specified directory from the given branch to main using rsync --delete
rsync -a --delete $branch/${branch#code-}/ main/

# Commit and push the changes
git add .
git commit -m "Copy ${branch#code-} directory from $branch to main"
git push

# Clean up stashes
git stash clear
