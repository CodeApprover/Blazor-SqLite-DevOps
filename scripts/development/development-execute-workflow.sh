#!/bin/bash

set -e  # Exit on any command failure
set -x  # Print all commands

# Check if the script is being run from the correct directory
CURRENT_DIR=$(basename "$(pwd)")
if [[ "$CURRENT_DIR" != "scripts" ]]; then
    echo "Error: Please run this script from within its own directory (scripts/)."
    exit 1
fi

function update_workflow_driver() {
    {
      echo "Push iteration: $1 of $2"
      echo "Branch: code-development"
      echo "Username: Code-Backups"
      echo "Email: 404bot@pm.me"
      echo "Automated push identifying push $1 of $2 iterations."
      cat bot.ascii
    } > "../development/$PROJ_NAME/workflow.driver"
}

# Constants
NUM_COMMITS=3
WAIT_DURATION=120 # seconds
MAIN_USER="Code-Backups"
MAIN_EMAIL="404bot@pm.me"
PROJ_NAME="Blazor-SqLite-DevOps"

# WARNING message
echo "CAUTION:"
echo "This script will perform the following operations:"
echo "Commits workflow.driver files"
echo "to the 'code-development' branch development directory"
echo "$NUM_COMMITS times every $WAIT_DURATION seconds."
echo "Three workflow.driver files will be committed to the 'code-development' branch."
echo ""
read -p "Do you wish to proceed? (y/n): " -r

# Check for the user's response
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Exiting without making changes."
    exit 2
fi

# Inform user about the operations
echo "Updating file for branch: code-development"

# Configure git
git config user.name "$MAIN_USER"
git config user.email "$MAIN_EMAIL"

# Checkout the branch
git fetch --all
git checkout "code-development"
git pull

# Committing and pushing in a loop
for i in $(seq 1 $NUM_COMMITS); do
    update_workflow_driver "$i" "$NUM_COMMITS"
    git add "../development/$PROJ_NAME/workflow.driver"
    git commit -m "Automated code-development push by $MAIN_USER #$i of $NUM_COMMITS"
    git push
    sleep $WAIT_DURATION
done

# Return to main branch and reset user
git config user.name "CodeApprover"
git config user.email "pucfada@pm.me"
git checkout main
git fetch --all
git pull
