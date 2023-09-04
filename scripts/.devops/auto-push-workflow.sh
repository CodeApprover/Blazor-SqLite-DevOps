#!/bin/bash

set -e  # Exit if any command fails.
set -x  # Print commands for debugging.

# Constants
NUM_COMMITS_DEFAULT=5
WAIT_DURATION_DEFAULT=100  # seconds
MAIN_USER="CodeApprover"
MAIN_EMAIL="pucfada@pm.me"
PROJ_NAME="Blazor-SqLite-Golf-Club"
ERROR_USAGE=2
ERROR_INVALID_BRANCH=3

BRANCHES=("main" "code-development" "code-staging" "code-production")

# Set caveat.
WARNING_MESSAGE=$(cat << EOM
CAUTION:

This script assumes that required users have the necessary permissions.

The script automates pushing workflow.driver changes
to a specific branch.

It performs the following tasks:
    1. Verifies the directory from which it is run.
    2. Accepts a branch name as an argument.
    3. Updates the 'workflow.driver' file with predefined content.
    4. Commits the updated file to the specified branch multiple times at a defined interval.
    5. Offers branch-specific directory selection for the 'main' branch.
    6. Restores the git environment after execution.

Consequences:
    1. The script will automate git operations that may affect the repository's branches and files.
    2. Incorrect usage or misconfiguration can lead to unexpected changes and loss of data.
    3. Use with caution and ensure you have backup copies of important files.

Exit Codes:
    0. Script executed successfully without errors.
    1. Incorrect script execution directory.
    2. Incorrect usage or missing argument.
    3. Invalid branch name as argument.
    4. User cancelled the operation after warning message.
    5. User cancelled during directory selection for the main branch.
EOM
)

echo "$WARNING_MESSAGE"

# Verify script execution directory
CURRENT_DIR=$(pwd)
EXPECTED_DIR="scripts/.devops"
if [[ "$CURRENT_DIR" != *"$EXPECTED_DIR" ]]; then
    echo "Error: Please run this script from within its own directory ($EXPECTED_DIR/)."
    exit 1
fi

# Check and parse command-line arguments
if [ $# -lt 1 ] || [ $# -gt 3 ]; then
    echo && echo "Usage: $0 <branch> [number_of_iterations] [wait_duration]"
    echo "Available options for <branch>: ${BRANCHES[*]}"
    exit $ERROR_USAGE
fi

# Verify the branch name provided as the first argument
branch=$1
if [[ ! " ${BRANCHES[*]} " =~ $branch ]]; then
    echo "Invalid branch: $branch. Available branches are: ${BRANCHES[*]}"
    exit $ERROR_INVALID_BRANCH
fi

# Parse the remaining command-line arguments
num_commits=$NUM_COMMITS_DEFAULT
wait_duration=$WAIT_DURATION_DEFAULT

if [ $# -ge 2 ]; then
    if ! [[ $2 =~ ^[0-9]+$ ]]; then
        echo "Invalid number of iterations: $2. Must be a positive integer."
        exit $ERROR_USAGE
    fi
    num_commits=$2
fi

if [ $# -ge 3 ]; then
    if ! [[ $3 =~ ^[0-9]+$ ]]; then
        echo "Invalid wait duration: $3. Must be a positive integer."
        exit $ERROR_USAGE
    fi
    wait_duration=$3
fi

# Ask user for confirmation
echo && read -p "Do you wish to proceed? (y/n): " -r
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Exiting without making changes."
    exit 4
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
                    exit 5
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

# Function to update workflow driver content
function update_workflow_driver() {
    {
        echo "Push iteration: $1 of $2 to branch: $branch by:"
        echo "Username: $USER_NAME Email: $USER_EMAIL"
        echo "Automated push $1 of $2"
        echo ""
    } > "$FILE_PATH"
}

# Commit and push in a loop.
for i in $(seq 1 "$num_commits"); do
    update_workflow_driver "$i" "$num_commits"
    git add "$FILE_PATH"
    git commit -m "Running $branch push #$i"
    git push

    # Countdown timer
    echo "Waiting for the next push..."
    for j in $(seq "$wait_duration" -1 1); do
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
