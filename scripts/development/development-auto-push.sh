#!/bin/bash

set -e  # Exit on any command failure
set -x  # Print all commands

# Branch Information
TARGET_BRANCH="code-development"
PROJ_NAME="Blazor-SqLite-DevOps"

# Constants
NUM_COMMITS=3
WAIT_DURATION=120 # seconds

# Set the current directory to the script's location
CURRENT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Check if the script is being run from the correct directory
EXPECTED_DIR="$CURRENT_DIR/scripts/$TARGET_BRANCH"
if [[ "$CURRENT_DIR" != "$EXPECTED_DIR" ]]; then
    echo "Error: Please run this script from within its own directory ($EXPECTED_DIR)."
    exit 1
fi

function update_workflow_driver() {
    {
        echo "Push iteration: $1 of $2"
        echo "Branch: $TARGET_BRANCH"
        echo "Username: $USER_NAME"
        echo "Email: $USER_EMAIL"
        echo "Automated push identifying push $1 of $2 iterations."
        cat bot.ascii
    } > "../development/$PROJ_NAME/workflow.driver"
}

# Determine user based on the selected branch
case "$TARGET_BRANCH" in
    main)
        USER_NAME="CodeApprover"
        USER_EMAIL="pucfada@pm.me"
    ;;
    code-development)
        USER_NAME="Code-Backups"
        USER_EMAIL="404bot@pm.me"
    ;;
    code-staging)
        USER_NAME="ScriptShifters"
        USER_EMAIL="lodgings@pm.me"
    ;;
    code-production)
        USER_NAME="CodeApprover"
        USER_EMAIL="pucfada@pm.me"
    ;;
    *)
        echo "Invalid branch: $TARGET_BRANCH"
        exit 1
    ;;
esac

# WARNING message
echo "CAUTION:"
echo "This script will perform the following operations:"
echo "Commits workflow.driver files"
echo "to the '$TARGET_BRANCH' branch development directory"
echo "$NUM_COMMITS times every $WAIT_DURATION seconds."
echo "Three workflow.driver files will be committed to the '$TARGET_BRANCH' branch."
echo ""
read -p "Do you wish to proceed? (y/n): " -r

# Check for the user's response
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Exiting without making changes."
    exit 2
fi

# Inform user about the operations
echo "Updating file for branch: $TARGET_BRANCH"

# Configure git
git config user.name "$USER_NAME"
git config user.email "$USER_EMAIL"

# Checkout the branch
git fetch --all
git checkout "$TARGET_BRANCH"
git pull

# Committing and pushing in a loop
for i in $(seq 1 $NUM_COMMITS); do
    update_workflow_driver "$i" "$NUM_COMMITS"
    git add "../development/$PROJ_NAME/workflow.driver"
    git commit -m "Automated $TARGET_BRANCH push by $USER_NAME #$i of $NUM_COMMITS"
    git push
    sleep $WAIT_DURATION
done

# Return to main branch and reset user
git config user.name "CodeApprover"
git config user.email "pucfada@pm.me"
git checkout main
git fetch --all
git pull
