#!/bin/bash

# Set strict mode for script execution
set -o errexit
set -o nounset
set -o pipefail

# Main script execution
branch="code-development"

# Set Git user to code-backups
git config user.name "code-backups" || { echo "Error setting Git user to code-backups."; exit 1; }

# Remove "code-" prefix from branch name
environment=${branch#"code-"}

# Determine the workflow.driver file path
workflow_driver="../../$environment/Blazor-SqLite-Golf-Club/workflow.driver"

# Check if the workflow.driver file exists
if [[ ! -f "$workflow_driver" ]]; then
    echo "workflow.driver file not found in $workflow_driver."
    exit 2
fi

# Git operations
git checkout "$branch" || { echo "Git checkout error on $branch."; exit 3; }
commit_msg="$(date +'%Y-%m-%d %H:%M:%S') - Automated push"
echo "$commit_msg" > "$workflow_driver"
git add "$workflow_driver" || { echo "Git add error."; exit 4; }
git commit -m "$commit_msg" || { echo "Git commit error."; exit 5; }
git push || { echo "Git push error."; exit 6; }

# Switch back to the main branch
git checkout main || { echo "Git checkout error returning to main."; exit 7; }

# Switch Git user back to codeapprover
git config user.name "codeapprover" || { echo "Error setting Git user to codeapprover."; exit 8; }
