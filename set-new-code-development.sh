#!/bin/bash

# Disable command echo
set +x

# Checkout the main branch
git checkout main

# Delete local and remote code-development branch
git branch -D code-development
git push origin --delete code-development

# Create new code-development branch
git branch code-development

# Delete any lock files
find . -type f -name '*lock*' -delete

# Push new code-development branch
git push --set-upstream origin code-development

# Checkout code-development
git checkout code-development

# Enable command echo
set -x
