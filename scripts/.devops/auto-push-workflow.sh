#!/bin/bash

# Set strict mode for script execution
set -o errexit
set -o nounset
set -o pipefail

# Function to generate a random 5-character string
generate_random_string() {
    cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 5 | head -n 1
}

# Main script execution
BRANCHES=("code-development" "code-staging" "code-production")
branch=$1

# Remove "code-" prefix from branch name
environment=${branch#"code-"}

# Determine the workflow.driver file path
workflow_driver="../../$environment/Blazor-SqLite-Golf-Club/workflow.driver"

# Check if the workflow.driver file exists
if [[ ! -f "$workflow_driver" ]]; then
    echo "workflow.driver file not found in $workflow_driver."
    exit 4
fi

# Git operations
git checkout "$branch" || { echo "Git checkout error on $branch."; exit 1; }
commit_msg="$(date +'%Y-%m-%d %H:%M:%S') - Automated push"
echo "$commit_msg" > "$workflow_driver"
git add "$workflow_driver" || { echo "Git add error."; exit 1; }
git commit -m "$commit_msg" || { echo "Git commit error."; exit 2; }
git push || { echo "Git push error."; exit 1; }
git checkout main || { echo "Git checkout error returning to main."; exit 3; }
echo "$commit_msg"
