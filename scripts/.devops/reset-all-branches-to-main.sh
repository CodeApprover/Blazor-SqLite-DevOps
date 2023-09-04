#!/bin/

set -e  # Exit if a command fails.
set -x  # Print commands for debugging.

# Set caveat message.
WARNING_MESSAGE=$(cat << EOM

CAUTION:

This script automates the recreation of
code-development, code-staging and code-production branches
using main as the source.

The script assumes that required users have the necessary permissions.

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
    1. User chose to exit the script without making changes.
    2. Production directory not found in the parent directory.
    3. Staging directory not found in the parent directory.
    4. Scripts directory not found in the parent directory.
    5. Development directory not found in the specified search path.

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
# Configure git user.
git config user.name "CodeApprover"
git config user.email "pucfada@pm.me"
# Checkout and update the main branch.
git checkout main
git stash
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
    # Extract the parent directory of the development directory.
    parent_dir=$(dirname "$development")
    # Use the parent directory to locate the other directories.
    production="$parent_dir/production"
    staging="$parent_dir/staging"
    scripts="$parent_dir/scripts"
    # Check if the directories exist.
    ! [[ -d "$production" ]] && echo "Production directory not found at: $production" && exit 2
    ! [[ -d "$staging" ]] && echo "Staging directory not found at: $staging" && exit 3
    ! [[ -d "$scripts" ]] && echo "Scripts directory not found at: $scripts" && exit 4
else
    ls -la "$CURRENT_DIR/../../"
    echo "Development directory not found." && exit 5
fi
# Set up code-development dirs.
git checkout -b code-development main
git rm -r "$production"
git rm -r "$staging"
for file in "$scripts"/*; do
    if [[ ! -e "$development/$(basename "$file")" ]]; then
        git rm "$file"
    fi
done
git commit -m "Setup new code-development branch. [skip ci]"
git push -u --set-upstream origin code-development
git checkout main
# Set up code-staging dirs.
git checkout -b code-staging main
git rm -r "$production"
for file in "$scripts"/*; do
    if [[ ! -e "$staging/$(basename "$file")" ]]; then
        git rm "$file"
    fi
done
git commit -m "Setup new code-staging branch. [skip ci]"
git push -u --set-upstream origin code-staging
git checkout main
# Set up code-production dirs.
git checkout -b code-production main
git rm -r "$development"
for file in "$scripts"/*; do
    if [[ ! -e "$staging/$(basename "$file")" ]]; then
        git rm "$file"
    fi
done
git commit -m "Setup new code-production branch. [skip ci]"
git push -u --set-upstream origin code-production
# Clean up and switch back to main branch.
git checkout main
git stash clear
git fetch --all --tags --prune
git pull
git status