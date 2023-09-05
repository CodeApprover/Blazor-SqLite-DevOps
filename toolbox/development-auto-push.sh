#!/bin/bash

set -e  # Exit nonzero if anything fails.
#set -x # Echo all commands.

# Set constants.
BRANCH="code-development"
BRANCH_DIR="${BRANCH//code-/}"
PROJ_NAME="Blazor-SqLite-Golf-Club"

# Set defaults without the USER_NAME variable.
NUM_COMMITS_DEFAULT=1
WAIT_DURATION_DEFAULT=100
DEFAULT_EXTRA_MSG=""

# Assign Git username and email based on branch.
case "$BRANCH" in
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
        echo "Invalid branch: $BRANCH"
        exit 1
    ;;
esac

# Set DEFAULT_COMMIT_MSG
DEFAULT_COMMIT_MSG="Commit iteration: $i of $NUM_COMMITS every $WAIT_DURATION seconds."
COMMIT_MSG=$DEFAULT_COMMIT_MSG

# Parse the number of command line arguments and assign values accordingly.
case $# in
    0)
        NUM_COMMITS=$NUM_COMMITS_DEFAULT
        WAIT_DURATION=$WAIT_DURATION_DEFAULT
        COMMIT_MSG=$DEFAULT_COMMIT_MSG
        EXTRA_MSG=$DEFAULT_EXTRA_MSG
    ;;
    1)
        NUM_COMMITS=$1
        WAIT_DURATION=$WAIT_DURATION_DEFAULT
        COMMIT_MSG=$DEFAULT_COMMIT_MSG
        EXTRA_MSG=$DEFAULT_EXTRA_MSG
    ;;
    2)
        NUM_COMMITS=$1
        WAIT_DURATION=$2
        COMMIT_MSG=$DEFAULT_COMMIT_MSG
        EXTRA_MSG=$DEFAULT_EXTRA_MSG
    ;;
    3)
        NUM_COMMITS=$1
        WAIT_DURATION=$2
        COMMIT_MSG=$3  # Override the default commit message
        EXTRA_MSG=$DEFAULT_EXTRA_MSG
    ;;
    4)
        NUM_COMMITS=$1
        WAIT_DURATION=$2
        COMMIT_MSG=$3  # Override the default commit message
        EXTRA_MSG=$4
    ;;
    *)
        # Provide usage instructions
        echo "Error: Invalid number of arguments. Expected 0 to 4 arguments, but got $#."
        echo "Usage:"
        echo "$0 [num_commits] [wait_duration] [commit_msg] [extra_msg]"
        exit 2
    ;;
esac

# Check the directory from which the script is being run.
EXPECTED_DIR="toolbox"
if [[ ! "$PWD" == *"$EXPECTED_DIR"* ]]; then
    echo "Error: Please run this script from its directory ($EXPECTED_DIR)."
    exit 3
fi

# Warning before executing the script.
echo "WARNING:"
echo "This script will:"
echo "- Commit workflow.driver files to the '$BRANCH' branch $BRANCH_DIR directory."
echo "- Make $NUM_COMMITS commits at intervals of $WAIT_DURATION seconds."
echo "Please ensure you are aware of the changes this script will make."
read -p "Do you wish to proceed? (y/n): " -r

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Exiting without making changes."
    exit 4
fi

# Fetch latest changes and switch to the target branch.
git config --global user.name "$USER_NAME"
git config --global user.email "$USER_EMAIL"
git fetch --all --tags --prune --prune-tags
git checkout "$BRANCH"
git stash
git pull

# Commit workflow.driver in a loop.
for i in $(seq 1 "$NUM_COMMITS"); do
    {
        echo "$COMMIT_MSG"
        echo "BRANCH: $BRANCH"
        echo "Username: $USER_NAME"
        echo "Email: $USER_EMAIL"
        echo "Date: $(date)"
        echo "$EXTRA_MSG"
    } >> "../${BRANCH//code-/}/$PROJ_NAME/workflow.driver"

    # Echo the commit message.
    echo
    if [ "$COMMIT_MSG" != "$DEFAULT_COMMIT_MSG" ]; then
        echo "Custom Commit Message: $COMMIT_MSG"
    else
        echo "Default Commit Message: $DEFAULT_COMMIT_MSG"
    fi

    # Echo the workflow.driver file.
    cat "../$BRANCH_DIR/$PROJ_NAME/workflow.driver" && echo

    # Commit and push the changes.
    git add "../$BRANCH_DIR/$PROJ_NAME/workflow.driver"
    git commit -m "$COMMIT_MSG"
    git push

    # Wait for the next commit.
    if [ "$i" -lt "$NUM_COMMITS" ]; then
        echo "Waiting for the next commit..."
        sleep "$WAIT_DURATION"
    fi
done

# Restore stashed changes and fetch latest changes.
git stash pop
git fetch --all --tags --prune --prune-tags
git pull
