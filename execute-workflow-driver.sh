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

# First commit and push to test workflows [skip ci]
echo "# use to commit a change, drive workflow execution" > workflow.driver
git add workflow.driver
git commit -m "running dev push to test workflows #0 [skip ci]"
git push

# Second commit and push to test workflows [skip ci]
echo "# use to drive workflow" > workflow.driver
git add workflow.driver
git commit -m "running dev push to test workflows #0 [skip ci]"
git push

# Third commit and push to test workflows [skip ci]
echo "# use to commit a change, drive workflow execution" > workflow.driver
git add workflow.driver
git commit -m "running dev push to test workflows #0"
git push

# Enable command echo
set -x
