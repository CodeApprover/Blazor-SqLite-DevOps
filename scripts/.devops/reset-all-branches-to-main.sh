#!/bin/bash

set -e
trap 'exit_handler ${LINENO} "$BASH_COMMAND"' ERR

# Script Description: Resets local main to remote main and updates the specific branches.
# Reads a configuration file (.config) for branch names, user details, and more.

# Exit codes and their descriptions
declare -A EXIT_MESSAGES
EXIT_MESSAGES=(
  [0]="Script completed successfully."
  [60]="User aborted the script."
  [61]="Usage error."
  [62]="Copy error."
  [63]="Remove error."
  [64]="Navigation error."
  [65]="Mkdir error."
  [66]="CD error."
  [67]="Branch error."
  [120]="Git config error."
  [121]="Git main error."
  [122]="Git create branch error."
  [123]="Git delete branch error."
  [124]="Git checkout error."
  [125]="Git stash error."
  [126]="Git push error."
  [127]="Git add error."
  [128]="Git commit error."
)

# Logging function
log_entry() {
  local message="$1"
  echo "$(date +'%Y-%m-%d %H:%M:%S') - $message"
}

# Exit handler function
exit_handler() {
  local line_num="$1"
  local cmd="$2"
  local exit_code="$?"
  log_entry "Error on line $line_num: $cmd"
  log_entry "${EXIT_MESSAGES[$exit_code]}"
  exit "$exit_code"
}

# Issue warning and parse user response
echo && echo "$WARNING"
echo && read -r -p "CONTINUE ??? [yes/no] " response
responses=("y" "Y" "yes" "YES" "Yes")
if [[ ! "${responses[*]}" =~ $response ]]; then
  log_entry "Aborted."
  exit_handler ${LINENO} "User aborted the script."
fi
echo

# Ensure we're in the correct directory
if [[ "$(pwd)" != *"$EXPECTED_DIR" ]]; then
  log_entry "Please run from $EXPECTED_DIR."
  exit_handler ${LINENO} "Usage error."
fi

# Move to root directory
cd ../.. || { log_entry "Navigation error."; exit_handler ${LINENO} "Navigation error."; }

# Set Git User
git config user.name "$DEVOPS_USER" || { log_entry "Git config user.name error."; exit_handler ${LINENO} "Git config user.name error."; }
git config user.email "$DEVOPS_EMAIL" || { log_entry "Git config user.email error."; exit_handler ${LINENO} "Git config user.email error."; }

# Ensure we're on the main branch
git checkout "${BRANCHES[3]}" || { log_entry "Checkout main error."; exit_handler ${LINENO} "Checkout main error."; }
git stash || { log_entry "Stash error on main."; exit_handler ${LINENO} "Stash error on main."; }

# Reset main branch to mirror remote
git fetch origin || { log_entry "Git fetch error."; exit_handler ${LINENO} "Git fetch error."; }
git reset --hard origin/main || { log_entry "Git reset error."; exit_handler ${LINENO} "Git reset error."; }

# Recreate each code- branch
for branch in "${BRANCHES[@]:0:3}"; do
  # Checkout, stash and delete local branch
  if git show-ref --verify --quiet "refs/heads/$branch"; then
    git checkout "$branch" || { log_entry "Checkout $branch error."; exit_handler ${LINENO} "Checkout $branch error."; }
    git stash || { log_entry "Stash error on $branch."; exit_handler ${LINENO} "Stash error on $branch."; }
    git checkout "${BRANCHES[3]}" || { log_entry "Checkout main error."; exit_handler ${LINENO} "Checkout main error."; }
    git branch -D "$branch" || { log_entry "Deleting branch $branch error."; exit_handler ${LINENO} "Deleting branch $branch error."; }
  fi

  # Delete remote branch if it exists
  if git ls-remote --heads origin "$branch" | grep -sw "$branch" >/dev/null; then
    git push origin --delete "$branch" || { log_entry "Deleting remote branch $branch error."; exit_handler ${LINENO} "Deleting remote branch $branch error."; }
  else
    log_entry "Remote branch $branch does not exist. Skipping deletion."
  fi

  # Create a new branch from main
  git checkout -b "$branch" || { log_entry "Error creating branch $branch."; exit_handler ${LINENO} "Error creating branch $branch."; }

  # Debug info
  log_entry "Current branch: $(git branch --show-current)"
  log_entry "Current directory: $(pwd)"

  # Create toolbox directory
  mkdir -p toolbox || { log_entry "Error creating toolbox."; exit_handler ${LINENO} "Error creating toolbox."; }

  # Confirm the required scripts directory exists and has content before copying
  env_name="${branch#code-}"
  if [[ -d "scripts/$env_name/" && $(ls -A "scripts/$env_name/") ]]; then
    cp -r "scripts/$env_name/"* toolbox/ || { log_entry "Error copying scripts to toolbox."; exit_handler ${LINENO} "Error copying scripts to toolbox."; }
  else
    log_entry "Directory scripts/$env_name/ does not exist or is empty."
  fi

  # Cleanup directories based on branch
  case "$branch" in
    "${BRANCHES[0]}") rm -rf staging production > /dev/null 2>&1 || { log_entry "Error removing directories from ${BRANCHES[0]}."; exit_handler ${LINENO} "Error removing directories from ${BRANCHES[0]}."; } ;;
    "${BRANCHES[1]}") rm -rf production > /dev/null 2>&1 || { log_entry "Error removing directories from ${BRANCHES[1]}."; exit_handler ${LINENO} "Error removing directories from ${BRANCHES[1]}."; } ;;
    "${BRANCHES[2]}") rm -rf development > /dev/null 2>&1 || { log_entry "Error removing directories from ${BRANCHES[2]}."; exit_handler ${LINENO} "Error removing directories from ${BRANCHES[2]}."; } ;;
  esac

  # Remove scripts
  rm -rf scripts || { log_entry "Error removing scripts."; exit_handler ${LINENO} "Error removing scripts."; }
  rm -rf .github/workflows || { log_entry "Error removing .github/workflows."; exit_handler ${LINENO} "Error removing .github/workflows."; }

  # Add, commit, and push to remote
  git add . || { log_entry "Git add error."; exit_handler ${LINENO} "Git add error."; }
  git commit -m "Updated $branch from main [skip ci]" || { log_entry "Git commit error."; exit_handler ${LINENO} "Git commit error."; }
  git push -u origin "$branch" || { log_entry "Git push error."; exit_handler ${LINENO} "Git push error."; }
done

# Final steps
git checkout "${BRANCHES[3]}" || { log_entry "Checkout main error."; exit_handler ${LINENO} "Checkout main error."; }
# Check if there are stashes to drop
if git stash list | grep -q 'stash@'; then
  git stash drop || { log_entry "Stash drop error."; exit_handler ${LINENO} "Stash drop error."; }
fi

# Navigate back to original directory
cd "$CUR_DIR" || { log_entry "Error navigating back to $CUR_DIR."; exit_handler ${LINENO} "Error navigating back to $CUR_DIR."; }

# Completion message
log_entry "$0 finished."
exit 0
