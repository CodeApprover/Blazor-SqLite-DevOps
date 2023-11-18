#!/bin/bash

# Set strict mode for script execution
set -o errexit
set -o nounset
set -o pipefail

BRANCHES=("code-development" "code-staging" "code-production")
branch=$1
git checkout "$branch" || { echo "Git checkout error on $branch."; exit 1; }
commit_msg="$(date +'%Y-%m-%d %H:%M:%S') - Automated push"
git add -A || { echo "Git add error."; exit 1; }
git commit -m "$commit_msg" || { echo "Git commit error."; exit 2; }
git push || { echo "Git push error."; exit 1; }
git checkout main || { echo "Git checkout error returning to main."; exit 3; }
