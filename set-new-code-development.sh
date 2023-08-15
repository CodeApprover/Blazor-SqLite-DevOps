#!/bin/bash

# Enable dettailed output
set +e

# Checkout and update the main branch
git checkout main
git stash
git pull

# Delete local and remote code-development branch
git branch -D code-development
git push origin --delete code-development

# Create new code-development branch
git checkout -b code-development

# Delete any lock files
find . -type f -name '*lock*' -delete

# Commit the changes with [skip ci] in the commit message
git add -A
git commit -m "Reset code-development branch [skip ci]"

# Push new code-development branch
git push --set-upstream origin code-development

# list dirs and files
ls -la

# Disable dettailed output
set -e
