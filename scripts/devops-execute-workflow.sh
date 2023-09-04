#!/bin/bash

set -e  # Exit on any command failure

# Constants
NUM_COMMITS=3
WAIT_DURATION=120 # seconds
MAIN_USER="CodeApprover"
MAIN_EMAIL="pucfada@pm.me"
PROJ_NAME="Blazor-SqLite-DevOps"

# Array of available branches
BRANCHES=("main" "code-development" "code-staging" "code-production")
MAIN_DIRS=("development" "staging" "production") # Directories in 'main' branch

# Validate the parameter
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <branch>"
    exit 1
fi

branch="$1"

# Validate branch
if [[ ! " ${BRANCHES[*]} " =~ $branch ]]; then
    echo "Invalid branch: $branch. Available branches are: ${BRANCHES[*]}"
    exit 2
fi

# Set directory and user info based on branch
case "$branch" in
    main)
        # If running main choose a directory
        while true; do
            echo "Available directories in main: ${MAIN_DIRS[*]}"
            read -r -p "Which directory do you want to update in main? (or 'cancel' to exit) " dir
            if [[ " ${MAIN_DIRS[*]} " =~ $dir ]]; then
                break
                elif [[ "$dir" == "cancel" ]]; then
                echo "User canceled. Exiting."
                exit 4
            else
                echo "Invalid directory. Try again or enter 'cancel' to exit."
            fi
        done
        FILE_PATH="$dir/$PROJ_NAME/workflow.driver"
        USER_NAME=$MAIN_USER
        USER_EMAIL=$MAIN_EMAIL
    ;;
    code-development)
        FILE_PATH="development/$PROJ_NAME/workflow.driver"
        USER_NAME="Code-Backups"
        USER_EMAIL="404bot@pm.me"
    ;;
    code-staging)
        FILE_PATH="staging/$PROJ_NAME/workflow.driver"
        USER_NAME="ScriptShifters"
        USER_EMAIL="lodgings@pm.me"
    ;;
    code-production)
        FILE_PATH="production/$PROJ_NAME/workflow.driver"
        USER_NAME="ScriptShifters"
        USER_EMAIL="lodgings@pm.me"
    ;;
esac

# Inform user about the operations
echo "Updating file: $FILE_PATH for branch: $branch"

# Configure git
git config user.name "$USER_NAME"
git config user.email "$USER_EMAIL"

# Checkout the branch
git fetch --all
git checkout "$branch"
git pull

# Committing and pushing in a loop
for i in $(seq 1 $NUM_COMMITS); do
    echo "Environment updating the workflow driver file - push #$i" >> "$FILE_PATH"
    git add "$FILE_PATH"
    git commit -m "Running $branch push #$i"
    git push
    sleep $WAIT_DURATION
done

# Return to main branch and reset user
git config user.name "$MAIN_USER"
git config user.email "$MAIN_EMAIL"
git checkout main
