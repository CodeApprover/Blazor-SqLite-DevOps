#!/bin/bash

# This script automates the process of updating and pushing changes to specific branches.
# It performs the following tasks:
# 1. Verifies the directory from which it is run.
# 2. Accepts a branch name as an argument.
# 3. Updates the 'workflow.driver' file with predefined content.
# 4. Commits the updated file to the specified branch multiple times at a defined interval.
# 5. Offers branch-specific directory selection for the 'main' branch.
# 6. Restores the git environment after execution.

# Exit Code Comments:
# 1: Incorrect script execution directory
# 2: Incorrect usage or missing argument
# 3: Invalid branch name as argument
# 4: User canceled the operation after being warned about the effects of the script
# 5: User canceled during directory selection for the 'main' branch

# set -x    # Print all commands for debugging
set -e      # Exit if any command fails

# Check if the script is being run from the correct directory
CURRENT_DIR=$(pwd)
EXPECTED_DIR="scripts/devops"
if [[ "$CURRENT_DIR" != *"$EXPECTED_DIR" ]]; then
    echo "Error: Please run this script from within its own directory ($EXPECTED_DIR/)."
    exit 1
fi

function update_workflow_driver() {
    {
        echo "Push iteration: $1 of $2 to branch: $branch by:"
        echo "Username: $USER_NAME Email: $USER_EMAIL"
        echo "Automated push $1 of $2"
        echo ""
        cat bot.ascii
    } > "$FILE_PATH"
}

# Constants
NUM_COMMITS=3
WAIT_DURATION=120   # seconds
MAIN_USER="CodeApprover"
MAIN_EMAIL="pucfada@pm.me"
PROJ_NAME="Blazor-SqLite-DevOps"

# Available branches
BRANCHES=("main" "code-development" "code-staging" "code-production")
MAIN_DIRS=("development" "staging" "production") # Directories in 'main' branch

# Check if no argument is provided
if [ $# -ne 1 ]; then
    echo "Usage: $0 <branch>"
    echo "Available options: ${BRANCHES[*]}"
    exit 2
fi

branch=$1

# Check if the provided branch is valid
if [[ ! " ${BRANCHES[*]} " =~ $branch ]]; then
    echo "Invalid branch: $branch. Available branches are: ${BRANCHES[*]}"
    exit 3
fi

# WARNING message
echo "CAUTION:"
echo "This script will perform the following operations:"
echo "1. Commits workflow.driver files to"
echo "   the '$branch' branch ${branch#code-} directory"
echo "   $NUM_COMMITS times every $WAIT_DURATION seconds."
echo "- Three workflow.driver files will be committed to the '$branch' branch."
echo ""
read -p "Do you wish to proceed? (y/n): " -r

# Check user response
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Exiting without making changes."
    exit 4
fi

# Set directory and user info based on branch
case "$branch" in
    main)
        # If running main choose a directory
        PS3='Which directory do you want to update in main? (or 4 to cancel): '
        select dir in "${MAIN_DIRS[@]}" "cancel"; do
            case $dir in
                development|staging|production)
                    break
                ;;
                cancel)
                    echo "User canceled. Exiting."
                    exit 5
                ;;
            esac
        done
        FILE_PATH="$dir/$PROJ_NAME/workflow.driver"
        USER_NAME=$MAIN_USER
        USER_EMAIL=$MAIN_EMAIL
    ;;
    code-development)
        FILE_PATH="../../development/$PROJ_NAME/workflow.driver"
        USER_NAME="Code-Backups"
        USER_EMAIL="404bot@pm.me"
    ;;
    code-staging)
        FILE_PATH="../../staging/$PROJ_NAME/workflow.driver"
        USER_NAME="ScriptShifters"
        USER_EMAIL="lodgings@pm.me"
    ;;
    code-production)
        FILE_PATH="../../production/$PROJ_NAME/workflow.driver"
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

# Committing and pushing in a loop
for i in $(seq 1 $NUM_COMMITS); do
    git pull
    update_workflow_driver "$i" "$NUM_COMMITS"
    git add "$FILE_PATH"
    git commit -m "$USER_NAME $branch automated workflow.driver push $i of $NUM_COMMITS"
    git push
    sleep $WAIT_DURATION
done

# Return to main and reset user and dir
git config user.name "$MAIN_USER"
git config user.email "$MAIN_EMAIL"
git checkout main
cd "$CURRENT_DIR"
