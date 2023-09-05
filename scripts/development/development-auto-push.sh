#!/bin/bash

set -e  # Exit nonzero if anything fails.
#set -x # Echo all commands.

# Set constants.
BRANCH="code-development"
BRANCH_DIR="${BRANCH//code-/}"
PROJ_NAME="Blazor-SqLite-Golf-Club"

# Set defaults without the USER_NAME variable.
NUM_COMMITS=1
WAIT_DURATION=100

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

# Check the number of arguments.
if [[ $# -gt 2 ]]; then
    echo "Error: Invalid number of arguments. Expected 0 to 2 arguments, but got $#."
    echo "Usage:"
    echo "$0 [num_commits] [wait_duration]"
    exit 2
fi

# Override defaults with command line arguments.
NUM_COMMITS=${1:-$NUM_COMMITS}
WAIT_DURATION=${2:-$WAIT_DURATION}

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

echo # Log readability.

# Commit workflow.driver in a loop.
for i in $(seq 1 "$NUM_COMMITS"); do
    COMMIT_MSG="$USER_NAME $BRANCH push $i of $NUM_COMMITS every $WAIT_DURATION seconds."
    {
        echo "$COMMIT_MSG"
        echo "Username: $USER_NAME push #$i/$NUM_COMMITS to $BRANCH branch."
    } > "../${BRANCH//code-/}/$PROJ_NAME/workflow.driver"
    
    # Echo the commit message.
    echo "Commit Message: $COMMIT_MSG"
    
    # Echo the workflow.driver file.
    echo "Workflow Driver File:"
    cat "../$BRANCH_DIR/$PROJ_NAME/workflow.driver"
    
    # Commit and push the changes.
    git add "../$BRANCH_DIR/$PROJ_NAME/workflow.driver"
    git commit -m "$COMMIT_MSG"
    git push
    
    # Wait for the next commit.
    if [ "$i" -lt "$NUM_COMMITS" ]; then
        echo "Waiting for the next commit..."
        for (( j=WAIT_DURATION; j>0; j-- )); do
            echo -ne "Seconds remaining... $j\r"
            sleep 1
        done
        echo " " # Clear the countdown line.
    fi
    
done

# Restore stashed changes and fetch latest changes.
git stash drop
git fetch --all --tags --prune --prune-tags
git pull
