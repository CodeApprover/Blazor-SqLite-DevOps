# Function to safely delete directories from the file system.
safe_delete_dir() {
    local dir_path="$1"
    if [[ -d "$dir_path" ]]; then
        rm -rf "$dir_path"
    fi
}

# Set up code-development dirs.
git checkout -b code-development main
safe_git_rm "$production"
safe_git_rm "$staging"
process_scripts_dir "code-development"
safe_delete_dir "scripts"  # Ensure the scripts directory is deleted.

# Add all changes,
git add .
git commit -m "Setup new code-development branch. [skip ci]"
git push -u --set-upstream origin code-development
git reset --hard HEAD
git checkout main

# Set up code-staging dirs.
git checkout -b code-staging main
safe_git_rm "$production"
process_scripts_dir "code-staging"
safe_delete_dir "scripts"  # Ensure the scripts directory is deleted.

# Add all changes,
git add .
git commit -m "Setup new code-staging branch. [skip ci]"
git push -u --set-upstream origin code-staging
git reset --hard HEAD
git checkout main

# Set up code-production dirs.
git checkout -b code-production main
safe_git_rm "$development"
process_scripts_dir "code-production"
safe_delete_dir "scripts"  # Ensure the scripts directory is deleted.

# Add all changes,
git add .
git commit -m "Setup new code-production branch. [skip ci]"
git push -u --set-upstream origin code-production
git reset --hard HEAD
git checkout main

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