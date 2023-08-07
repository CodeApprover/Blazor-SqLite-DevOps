#!/bin/bash
set -e
set -x

if [[ "${PWD}" == *scripts/lib ]]; then
    cd ../..
elif [[ "${PWD}" == *scripts ]]; then
    cd ..
fi

git checkout main

REPO_DIR=$(pwd)
valid_branches=("code-development" "code-staging" "code-production")
branch=$1

temp_dir="$REPO_DIR/temp_dir"
temp_branch="temp_branch"
remoteURL=$(git remote -v | grep fetch | awk '{print $2}')

if [[ -d "$temp_dir" ]]; then
    rm -rf "$temp_dir"
fi
mkdir "$temp_dir"

if git rev-parse --verify "$temp_branch"; then
    git branch -D "$temp_branch"
fi

# Check if the branch exists remotely
if git ls-remote --exit-code --heads origin "$branch"; then
    # If the branch exists remotely, clone the remote branch into temp_dir
    git clone "$remoteURL" -b "$branch" "$temp_dir"
    git checkout "$branch"

    # Retain necessary GitHub-related files (e.g., .git, .gitignore)
    for file in .git .gitignore; do
        if [[ -e "$REPO_DIR/$file" ]]; then
            mv "$REPO_DIR/$file" "$temp_dir/$file"
        fi
    done

    # Remove all other files in the local branch except .git
    find "$REPO_DIR" -mindepth 1 -maxdepth 1 ! -name ".git" -exec rm -rf {} \;

    # Move the files from temp_dir to the local branch
    mv "$temp_dir"/* "$REPO_DIR/"
    rmdir "$temp_dir"
else
    # If the branch doesn't exist remotely, check locally
    if git rev-parse --verify "$branch"; then
        # If the branch exists locally, replace its files with the ones from temp_dir
        git checkout "$branch"
        git stash push -u -m "Stash old $branch"
        git branch -D "$branch"

        # Remove all files in the local branch except .git and .gitignore
        find "$REPO_DIR" -mindepth 1 ! -regex "^$REPO_DIR/.git.*" -delete

        # Move the files from temp_dir to the local branch
        mv "$temp_dir"/* "$REPO_DIR/"
        rmdir "$temp_dir"
    else
        # If the branch doesn't exist anywhere, clone the remote "main" branch into temp_dir
        git clone "$remoteURL" -b main "$temp_dir"
        git checkout main

        # Create the new branch locally
        git checkout -b "$branch"

        # Copy the files from temp_dir to the new local branch
        cp -rv "$temp_dir"/* "$REPO_DIR"
    fi
fi

git checkout "$branch"
git stash push -u -m "Stashing untracked files in $branch"

# Strip 'code-' from the branch name to get the desired directory name
desired_dir_name="${branch#code-}"

# Check and rename the directory if necessary
for dir in development staging production; do
    if [[ "$dir" == "$desired_dir_name" ]]; then
        # If the directory already exists, we don't need to do anything
        break
    fi
    if [[ -d "$dir" ]]; then
        # Rename the directory to the desired name
        git mv "$dir" "$desired_dir_name"
    fi
done

if [[ -d "$temp_dir" ]]; then
    rm -rf "$temp_dir"
fi
if git rev-parse --verify "$temp_branch"; then
    git branch -D "$temp_branch"
fi

git add .

exit 0
