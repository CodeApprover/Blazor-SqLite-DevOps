#!/bin/bash

# This script automates the process of resetting all branches to the main branch.

# It performs the following tasks:
# 1. Verifies the directory from which it is run.
# 2. Resets all branches to the main branch.

# Exit Code Comments:
# 1: Incorrect script execution directory
# 2: User canceled the operation after being warned about the effects of the script

# set -x  # Print all commands for debugging
set -e    # Exit if any command fails

# Check if the script is being run from the correct directory
CURRENT_DIR=$(pwd)
EXPECTED_DIR="scripts/devops"
if [[ "$CURRENT_DIR" != *"$EXPECTED_DIR" ]]; then
    echo "Error: Please run this script from within its own directory ($EXPECTED_DIR/)."
    exit 1
fi

# WARNING message
echo "CAUTION:"
echo "This script will reset all branches to the 'main' branch."
read -p "Do you wish to proceed? (y/n): " -r

# Check user response
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Exiting without making changes."
    exit 2
fi

# Logging in as user 'CodeApprover'
git config user.name "CodeApprover"
git config user.email "pucfada@pm.me"

# Resetting branches to 'main'
for branch in "code-development" "code-staging" "code-production"; do
    git checkout "$branch"
    git reset --hard main
    git push origin "$branch" --force
done

# Return to main branch and reset directory
git checkout main
cd "$CURRENT_DIR"
