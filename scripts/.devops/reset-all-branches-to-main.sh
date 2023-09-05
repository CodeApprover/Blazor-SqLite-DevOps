#!/bin/bash

set -e  # Exit if a command fails.
#set -x # Print commands for debugging.

# Set caveat.
WARNING_MESSAGE=$(cat << EOM
CAUTION:

This script assumes that required users have the necessary permissions.

The script automates the recreation of the
code-development, code-staging and code-production branches
using main as the source.

    It performs the following tasks:

        1. Checkout and update of the main branch.
        2. DELETE all local and remote branches except 'main'.
        3. Create and setup fresh branches named 'code-development', 'code-staging' and 'code-production' based on 'main'.
        4. Ensure that each code- branch only has its specific required directories and files.
        5. Returns to the main branch.

    Consequences:

        1. Any unmerged changes in deleted branches will be LOST FOREVER.
        2. The deleted branches on the remote could impact other collaborators' work.
        3. The operations are irreversible. Ensure you have a backup if needed.
        4. All stashes will be dropped and lost.

    Exit Codes:

        0. Script executed successfully without errors.
        1. User chose to exit without making changes.
        2. Run script from the correct directory.
        3. Production directory not found in the parent directory.
        4. Staging directory not found in the parent directory.
        5. Scripts directory not found in the parent directory.
        6. Development directory not found in the specified search path.
EOM
)

# Issue warning.
echo "$WARNING_MESSAGE"

# Check user response.
echo && read -p "Do you wish to proceed? (y/n): " -r
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    echo "Exiting without making changes."
    exit 1
fi

# Normalise path separators based on operating system.
OS=$(uname)
CURRENT_DIR=$(pwd)
if [[ "$OS" != "Linux" ]]; then # Windows/MinGW.
    CURRENT_DIR=${CURRENT_DIR//\\/\/}
fi

# Check if script is run from correct directory.
EXPECTED_DIR="scripts/.devops"
if [[ "$CURRENT_DIR" != *"$EXPECTED_DIR" ]]; then
    echo "Error: Please run this script from within its own directory ($EXPECTED_DIR/)."
    exit 2
fi

# Configure git user.
git config user.name "CodeApprover" --local
git config user.email "pucfada@pm.me" --local

# Navigate to repository root
cd "$CURRENT_DIR/../../"

# Checkout and update the main branch.
git checkout main
git stash # Prevents uncommitted changes error.
git fetch --all --tags --prune
git pull

# Set branch names.
branches=("code-development" "code-staging" "code-production")

# Delete local branches.
for branch in "${branches[@]}"; do
    if git show-ref --quiet "refs/heads/$branch"; then
        git branch -D "$branch"
    fi
done

# Delete remote branches.
for remote_branch in "${branches[@]}"; do
    if git show-ref --quiet "refs/remotes/origin/$remote_branch"; then
        git push origin --delete "$remote_branch"
    fi
done

# Find the development directory.
development=$(find "$CURRENT_DIR/../../" -type d -name "development" | head -n 1)

# If the development directory is found.
if [[ -n "$development" ]]; then
    # Extract parent directory of development directory.
    parent_dir=$(dirname "$development")

    # Use parent directory to locate the other directories.
    production="$parent_dir/production"
    staging="$parent_dir/staging"
    scripts="$parent_dir/scripts"

    # Check if required directories exist.
    ! [[ -d "$production" ]] && echo "Production directory not found at: $production" && exit 3
    ! [[ -d "$staging" ]] && echo "Staging directory not found at: $staging" && exit 4
    ! [[ -d "$scripts" ]] && echo "Scripts directory not found at: $scripts" && exit 5
else
    ls -la "$CURRENT_DIR/../../"
    echo "Development directory not found." && exit 6
fi

# Function to git remove files or dirs safely.
safe_git_rm() {
    local path="$1"
    if [[ -e "$path" ]]; then  # Checks if the file or directory exists.
        git rm -r "$path"
    fi
}

# Function to process the scripts directory for each branch.
process_scripts_dir() {
    local branch="$1"
    subdir=${branch//code-/}

    # Check if the specific subdir exists.
    if [[ ! -d "$scripts/$subdir" ]]; then
        echo "Error: $subdir directory not found in $scripts. Exiting..."
        exit 7  # Using exit code 7 to indicate this specific error.
    fi

    # Create the toolbox directory if it doesn't exist.
    mkdir -p "toolbox"

    # Copy the contents of the subdir to 'toolbox' in the project root.
    cp -r "$scripts/$subdir/"* "toolbox/"

    # Remove the entire scripts directory from git and the file system.
    git rm -r "$scripts"

    # Ensure the directory is removed from the file system.
    if [[ -d "$scripts" ]]; then
        rm -rf "$scripts"
    fi

    # Add the new scripts directory to git.
    cd "toolbox"
    git add -A
    cd -  # Navigate back to the original directory to ensure the rest of the script runs correctly.
}

# Function to set up code branches.
setup_code_branch() {
    local branch="$1"

    # Create a new branch and check it out.
    git checkout -b "$branch"

    # Process the directory based on the branch type.
    case "$branch" in
        "code-development")
            safe_git_rm "$production"
            safe_git_rm "$staging"
            ;;
        "code-staging")
            safe_git_rm "$production"
            ;;
        "code-production")
            safe_git_rm "$development"
            ;;
    esac

    # Process the scripts directory.
    process_scripts_dir "$branch"
    safe_git_rm "scripts"

    # Add all changes and push to create a new remote branch.
    git add .
    git commit -m "Setup new $branch branch. [skip ci]"

    # Push the branch to remote.
    git push origin "$branch"

    # Fetch the new branch from remote.
    git fetch origin "$branch"

    # Set up the local branch to track the remote branch.
    git branch -u "origin/$branch" "$branch"

    # Reset and return to main branch.
    git reset --hard HEAD
    git checkout main
}

# Set up the code branches.
for branch in "${branches[@]}"; do
    setup_code_branch "$branch"
done

# Switch back to main branch.
git checkout main
git stash clear
git fetch --all --tags --prune
git pull
git status
git branch -a

# Set line ending conversion tool.
LINE_ENDING_TOOL="unix2dos"
if [[ "$OS" == "Linux" ]]; then
    LINE_ENDING_TOOL="dos2unix"
fi

# Process line ending conversion.
find "$CURRENT_DIR" -type f -exec "$LINE_ENDING_TOOL" {} \;

# Remove trailing spaces from all lines.
find "$CURRENT_DIR" -type f -exec sed -i 's/[[:space:]]*$//' {} \;

# Replace multiple consecutive empty lines with one.
find "$CURRENT_DIR" -type f -exec sed -i '/^$/N;/^\n$/D' {} \;

# Add all changes, commit and push.
git add -A
git commit -m "Finalising scripts [skip ci]"
git push
