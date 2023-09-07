#!/bin/bash

# Define exit codes
SUCCESS=0
USER_ABORT=1
INCORRECT_DIRECTORY=2
PRODUCTION_DIR_NOT_FOUND=3
STAGING_DIR_NOT_FOUND=4
SCRIPTS_DIR_NOT_FOUND=5
DEVELOPMENT_DIR_NOT_FOUND=6
MISSING_SUBDIR=7
FINALIZE_ERROR=8

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

        $SUCCESS. Script executed successfully without errors.
        $USER_ABORT. User chose to exit without making changes.
        $INCORRECT_DIRECTORY. Run script from the correct directory.
        $PRODUCTION_DIR_NOT_FOUND. Production directory not found in the parent directory.
        $STAGING_DIR_NOT_FOUND. Staging directory not found in the parent directory.
        $SCRIPTS_DIR_NOT_FOUND. Scripts directory not found in the parent directory.
        $DEVELOPMENT_DIR_NOT_FOUND. Development directory not found in the specified search path.
        $MISSING_SUBDIR. Subdirectory not found in the scripts directory.
        $FINALIZE_ERROR. Error occurred during finalizing scripts.
EOM
)

# Issue warning.
echo "$WARNING_MESSAGE"

# Check user response.
echo && read -p "Do you wish to proceed? (y/n): " -r
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    echo "Exiting without making changes."
    exit "$USER_ABORT"
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
    exit "$INCORRECT_DIRECTORY"
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
    ! [[ -d "$production" ]] && echo "Production directory not found at: $production" && exit "$PRODUCTION_DIR_NOT_FOUND"
    ! [[ -d "$staging" ]] && echo "Staging directory not found at: $staging" && exit "$STAGING_DIR_NOT_FOUND"
    ! [[ -d "$scripts" ]] && echo "Scripts directory not found at: $scripts" && exit "$SCRIPTS_DIR_NOT_FOUND"
else
    ls -la "$CURRENT_DIR/../../"
    echo "Development directory not found." && exit "$DEVELOPMENT_DIR_NOT_FOUND"
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
        exit "$MISSING_SUBDIR"
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

# Check for duplicate user.name in git config
if [[ $(git config --get-all user.name | wc -l) -gt 1 ]]; then
  last_user_name=$(git config --get-all user.name | tail -n 1)
  git config --unset-all user.name
  git config user.name "$last_user_name"
fi

# Check for duplicate user.email in git config
if [[ $(git config --get-all user.email | wc -l) -gt 1 ]]; then
  last_user_email=$(git config --get-all user.email | tail -n 1)
  git config --unset-all user.email
  git config user.email "$last_user_email"
fi

# Exit successfully
exit "$SUCCESS"
