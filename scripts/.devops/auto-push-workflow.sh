#!/bin/bash

set -e  # Exit if any command fails.
set -x # Print commands for debugging.

# Constants
NUM_COMMITS_DEFAULT=3
WAIT_DURATION_DEFAULT=45  # seconds
MAIN_USER="CodeApprover"
MAIN_EMAIL="pucfada@pm.me"
PROJ_NAME="Blazor-SqLite-Golf-Club"
CURRENT_DIR=$(pwd)
BRANCHES=("main" "code-development" "code-staging" "code-production")

# Exit Codes
SUCCESS=0
ERROR_DIR=1
ERROR_USAGE=2
ERROR_INVALID_BRANCH=3
ERROR_USER_CANCELLED=4
ERROR_DIR_SELECTION_CANCELLED=5

# Set caveat.
WARNING_MESSAGE=$(cat << EOM
CAUTION:

This script automates pushing workflow.driver changes to a specific branch
and assumes that required users have the necessary permissions.

# ... (rest of the warning message) ...
EOM
)

echo "$WARNING_MESSAGE"

CURRENT_DIR=$(pwd)
EXPECTED_DIR="scripts/.devops"
if [[ "$CURRENT_DIR" != *"$EXPECTED_DIR" ]]; then
    echo "Error: Please run this script from within its own directory ($EXPECTED_DIR/)."
    exit $ERROR_DIR
fi

# Check if no argument is provided
if [ $# -lt 1 ]; then
    echo "Usage: $0 <branch> [number_of_iterations] [wait_duration]"
    echo "Available options for <branch>: ${BRANCHES[*]}"
    exit $ERROR_USAGE
fi

branch=$1
if [[ ! " ${BRANCHES[*]} " =~ $branch ]]; then
    echo "Invalid branch: $branch. Available branches are: ${BRANCHES[*]}"
    exit $ERROR_INVALID_BRANCH
fi

num_commits=${2:-$NUM_COMMITS_DEFAULT}
wait_duration=${3:-$WAIT_DURATION_DEFAULT}

echo && read -p "Do you wish to proceed? (y/n): " -r
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Exiting without making changes."
    exit $ERROR_USER_CANCELLED
fi

# Stash uncommitted changes in the current branch.
if [[ $(git status --porcelain) ]]; then
    echo "Stashing uncommitted changes in current branch..."
    git stash
    CURRENT_BRANCH_STASHED=true
fi

# Stash changes for the target branch.
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
git checkout "$1"
if [[ $(git status --porcelain) ]]; then
    echo "Stashing uncommitted changes on branch $1..."
    git stash
    TARGET_BRANCH_STASHED=true
fi
git checkout "$CURRENT_BRANCH"

# Extract MAIN_DIRS from BRANCHES and set the FILE_PATH.
for branch_item in "${BRANCHES[@]}"; do
    case "$branch_item" in
        main)
            MAIN_DIRS=("development" "staging" "production")
        ;;
        code-*)
            MAIN_DIRS=("${branch_item#code-}")
        ;;
    esac
done

case "$branch" in
    main)
        PS3='Which directory do you want to update in main? (or 4 to cancel): '
        select dir in "${MAIN_DIRS[@]}" "cancel"; do
            case $dir in
                development|staging|production)
                    break
                ;;
                cancel)
                    echo "User cancelled. Exiting."
                    exit $ERROR_DIR_SELECTION_CANCELLED
                ;;
            esac
        done
        FILE_PATH="$CURRENT_DIR/../../$dir/$PROJ_NAME/workflow.driver"
        USER_NAME=$MAIN_USER
        USER_EMAIL=$MAIN_EMAIL
    ;;
    code-*)
        dir="${branch#code-}"
        FILE_PATH="$CURRENT_DIR/../../$dir/$PROJ_NAME/workflow.driver"
        USER_NAME=$MAIN_USER
        USER_EMAIL=$MAIN_EMAIL
    ;;
esac

# Inform user about the operations.
echo "Updating file: $FILE_PATH for branch: $branch"

# Configure git
git config --replace-all user.name "$USER_NAME"
git config --replace-all user.email "$USER_EMAIL"

# Checkout the branch
git fetch --all
git checkout "$branch"
git pull

function update_workflow_driver() {
    {
        echo "Push iteration: $1 of $2 to branch: $branch by:"
        echo "Username: $USER_NAME Email: $USER_EMAIL"
        echo "Automated push $1 of $2"
        echo ""
    } > "$FILE_PATH"
}

# Commit and push in a loop.
for i in $(seq 1 $num_commits); do
    update_workflow_driver "$i" "$num_commits"
    git add "$FILE_PATH"
    git commit -m "Running $branch push #$i"
    git push

    # Countdown timer
    echo "Waiting for the next push..."
    for j in $(seq $wait_duration -1 1); do
        echo -ne "$j seconds remaining...\r"
        sleep 1
    done
    echo
done

# Return to main and reset user and dir.
git config --replace-all user.name "$MAIN_USER"
git config --replace-all user.email "$MAIN_EMAIL"
git checkout main
cd "$CURRENT_DIR"

# Pop the stash for the target branch.
if [[ $TARGET_BRANCH_STASHED == true ]]; then
    git checkout "$1"
    git stash pop
    git checkout "$CURRENT_BRANCH"
fi

# Pop the stash for the current branch.
if [[ $CURRENT_BRANCH_STASHED == true ]]; then
    git stash pop
fi

exit $SUCCESS
