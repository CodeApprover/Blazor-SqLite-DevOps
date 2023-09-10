#!/bin/bash

# The script resets local main to remote main.
# It then resets and updates the code-development, code-staging and code-production branches,
# both locally and remotely.

# It read a configuration file (.config)
# to populate parameters such as branch names, user details, etc.

# Exit codes
SUCCESS=0
USER_ABORT=61
USAGE_ERR=62
RM_ERR=127
CP_ERR=128
MKDIR_ERR=129

# Git exit codes
GIT_CONFIG_ERR=111
GIT_MAIN_ERR=121
GIT_BRANCH_DEL_ERR=122
GIT_BRANCH_CREATE_ERR=123
GIT_CHECKOUT_ERR=124
GIT_STASH_ERR=125
GIT_PUSH_ERR=126

# Set constants from .config
mapfile -t CONFIG_VALUES < <(grep -vE '^#|^[[:space:]]*$' .config)
DEVOPS_USER="${CONFIG_VALUES[0]}"
DEVOPS_EMAIL="${CONFIG_VALUES[1]}"
EXPECTED_DIR="${CONFIG_VALUES[3]}"
BRANCHES=("${CONFIG_VALUES[4]}" "${CONFIG_VALUES[5]}" "${CONFIG_VALUES[6]}" "${CONFIG_VALUES[7]}")

# Warning message
WARNING=$(cat << EOM

WARNING: You are about to execute $0

This script replaces local ${BRANCHES[3]} with remote ${BRANCHES[3]},
and then resets the ${BRANCHES[0]}, ${BRANCHES[1]} and ${BRANCHES[2]}
branches both locally and remotely.

The script reads parameters from:
$(pwd)/.config

USAGE: $0

CAUTION: This script could result in losing unsaved work.
         Consider making a backup of all branches before execution.

EOM
)

# Logging function
log_entry() {
  local message="$1"
  echo "$(date +'%Y-%m-%d %H:%M:%S') - $message"
}

# Issue warning and parse user response
echo && echo "$WARNING"
echo && read -r -p "CONTINUE ??? [yes/no] " response
responses=("y" "Y" "yes" "YES" "Yes")
[[ ! "${responses[*]}" =~ $response ]] && log_entry "Aborted." && exit "$USER_ABORT"
echo

# Ensure correct directory
if [[ "$(pwd)" != *"$EXPECTED_DIR" ]]; then
  log_entry "Error: Must run from $EXPECTED_DIR."
  exit "$USAGE_ERR"
fi

# ===============================================
# Main Script Logic
# ===============================================

# Set Git User
git config user.name "$DEVOPS_USER" || { log_entry "Git config user.name failed."; exit "$GIT_CONFIG_ERR"; }
git config user.email "$DEVOPS_EMAIL" || { log_entry "Git config user.email failed."; exit "$GIT_CONFIG_ERR"; }

# Ensure main branch
git checkout "${BRANCHES[3]}" || { log_entry "Git checkout main failed."; exit "$GIT_CHECKOUT_ERR"; }
git stash || { log_entry "Git stash failed for main."; exit "$GIT_STASH_ERR"; } # Stash changes to prevent issues

# Reset Main
git fetch origin || { log_entry "Git fetch failed."; exit "$GIT_MAIN_ERR"; }
git reset --hard origin/main || { log_entry "Git reset main failed."; exit "$GIT_MAIN_ERR"; }

# Branch Operations
for branch in "${BRANCHES[@]:0:3}"; do

  # Check if the branch exists locally, stash changes, switch to main, delete branch
  if git show-ref --verify --quiet "refs/heads/$branch"; then
    git checkout "$branch" || { log_entry "Git checkout $branch failed."; exit "$GIT_CHECKOUT_ERR"; }
    git stash || { log_entry "Git stash failed for $branch."; exit "$GIT_STASH_ERR"; }
    git checkout "${BRANCHES[3]}" || { log_entry "Git checkout main failed."; exit "$GIT_CHECKOUT_ERR"; } # Switch to main branch
    git branch -D "$branch" || { log_entry "Git delete $branch failed."; exit "$GIT_BRANCH_DEL_ERR"; }
  fi

  # Check if the branch exists remotely and delete it
  if git ls-remote --heads origin "$branch" | grep -sw "$branch" >/dev/null; then
    git push origin --delete "$branch" || { log_entry "Git delete remote $branch failed."; exit "$GIT_BRANCH_DEL_ERR"; }
  fi

  # Create new code- branch from main
  git checkout -b "$branch" || { log_entry "Git checkout new $branch failed."; exit "$GIT_BRANCH_CREATE_ERR"; }

  # Remove all files in the branch, including hidden ones
  rm -rf ./* ./.[^.]* || { log_entry "Directory cleanup failed."; exit "$RM_ERR"; }

  # Copy only required directories to branch
  env_name="${branch#code-}"
  case "$branch" in
    "${BRANCHES[0]}")
      cp -r "../development" . || { log_entry "Copy operation for development failed."; exit "$CP_ERR"; }
      ;;
    "${BRANCHES[1]}")
      cp -r "./development" . || { log_entry "Copy operation for development failed."; exit "$CP_ERR"; }
      cp -r "./staging" . || { log_entry "Copy operation for staging failed."; exit "$CP_ERR"; }
      ;;
    "${BRANCHES[2]}")
      cp -r "./staging" . || { log_entry "Copy operation for staging failed."; exit "$CP_ERR"; }
      cp -r "../production" . || { log_entry "Copy operation for production failed."; exit "$CP_ERR"; }
      ;;
  esac

  # Copy required scripts to code- toolbox dir
  mkdir -p toolbox || { log_entry "Toolbox directory creation failed."; exit "$MKDIR_ERR"; }
  cp -r "../scripts/$env_name/*" toolbox/ || { log_entry "Copy operation for toolbox failed."; exit "$CP_ERR"; }

  # Add, commit and push code- branch to remote
  git add . || { log_entry "Git add failed for $branch."; exit "$GIT_MAIN_ERR"; }
  git commit -m "Updated $branch from main"
  git push -u origin "$branch" || { log_entry "Git push to $branch failed."; exit "$GIT_PUSH_ERR"; }

done

# Cleanup
git checkout main || { log_entry "Git checkout main failed."; exit "$GIT_CHECKOUT_ERR"; }
git stash drop || { log_entry "Git stash drop failed."; exit "$GIT_STASH_ERR"; }

# Finish
log_entry "$0 completed successfully."
exit "$SUCCESS"
