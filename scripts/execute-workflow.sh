#!/bin/bash

# Array of available options
available_options=("code-development" "code-staging" "code-production")

# Set the number of commits and pause duration
num_commits=3
pause_duration=120 # seconds

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

# Configure git user based on the branch
case $branch in
    code-development)
        git config user.name "Code-Backups"
        git config user.email "404bot@pm.me"
    ;;
    code-staging)
        git config user.name "ScriptShifters"
        git config user.email "lodgings@pm.me"
    ;;
    code-production)
        git config user.name "CodeApprover"
        git config user.email "pucfada@pm.me"
    ;;
esac

# WARNING message
echo "CAUTION:"
echo "This script will perform the following operations:"
echo "1. Commit $num_commits workflow.driver files to the '$branch' branch ${branch#code-} directory."
echo ""
echo "Consequences:"
echo "- The workflow.driver files will be committed to the '$branch' branch."
echo ""
read -p "Do you wish to proceed? (y/n): " -r

# Check for the user's response
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Exiting without making changes."
    exit 1
fi

# Checkout and update branch
git fetch --all
git checkout $branch
git pull

# Commit and push to test workflows
for num in $(seq 1 $num_commits); do
    echo "$num" >> workflow.driver
    git add workflow.driver
    git commit -m "Running $branch push #$num"
    git push
    sleep $pause_duration
done
