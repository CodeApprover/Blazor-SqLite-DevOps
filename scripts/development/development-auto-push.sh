#!/bin/bash

set -e  # Exit on any command failure.
set -x  # Print all commands.

# Constants
PROJ_NAME="Blazor-SqLite-Golf-Club"

# Remember the current branch to revert to it later.
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)

# Constants with default values.
DEFAULT_BRANCH="code-development"
NUM_COMMITS_DEFAULT=1
WAIT_DURATION_DEFAULT=100 # seconds.

# Check and parse command-line arguments
TARGET_BRANCH=${1:-$DEFAULT_BRANCH}
NUM_COMMITS=${2:-$NUM_COMMITS_DEFAULT}
WAIT_DURATION=${3:-$WAIT_DURATION_DEFAULT}

# Set branch information.
BRANCH="${TARGET_BRANCH//code-}"

# Check if the script is being run from the correct directory
EXPECTED_DIR="scripts/$BRANCH"
if [[ ! "$PWD" =~ $EXPECTED_DIR ]]; then
    echo "Error: Please run this script from within its own directory ($EXPECTED_DIR)."
    exit 1
fi

# Determine user based on the selected branch.
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

# WARNING message.
echo "CAUTION:"
echo "This script will perform the following operations:"
echo "Commits workflow.driver files"
echo "to the '$TARGET_BRANCH' branch development directory"
echo "$NUM_COMMITS times every $WAIT_DURATION seconds."
echo "Three workflow.driver files will be committed to the '$TARGET_BRANCH' branch."
echo ""
read -p "Do you wish to proceed? (y/n): " -r

# Check for the user's response.
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Exiting without making changes."
    exit 2
fi

# Inform user about the operations.
echo "Updating file for branch: $TARGET_BRANCH"

# Configure git globally.
git config --global user.name "$USER_NAME"
git config --global user.email "$USER_EMAIL"

# Checkout the branch.
git fetch --all
git checkout "$TARGET_BRANCH"
git pull

# Committing and pushing in a loop.
for i in $(seq 1 $NUM_COMMITS); do
    echo "Push iteration: $i of $NUM_COMMITS" >> "../../development/$PROJ_NAME/workflow.driver"
    echo "Branch: $TARGET_BRANCH" >> "../../development/$PROJ_NAME/workflow.driver"
    echo "Username: $USER_NAME" >> "../../development/$PROJ_NAME/workflow.driver"
    echo "Email: $USER_EMAIL" >> "../../development/$PROJ_NAME/workflow.driver"
    echo "Date: $(date)" >> "../../development/$PROJ_NAME/workflow.driver"

    git add "../../development/$PROJ_NAME/workflow.driver" # Corrected path
    git commit -m "Automated $TARGET_BRANCH push by $USER_NAME #$i of $NUM_COMMITS"
    git push

    # Countdown timer
    if [ "$i" -lt "$NUM_COMMITS" ]; then
        echo "Waiting for the next push..."
        for j in $(seq "$WAIT_DURATION" -1 1); do
            echo -ne "$j seconds remaining...\r"
            sleep 1
        done
        echo
    fi
done

# Return to the original branch and reset user.
git config --global user.name "CodeApprover"
git config --global user.email "pucfada@pm.me"
git checkout "$CURRENT_BRANCH"
git fetch --all
git pull
