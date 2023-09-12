#!/bin/bash

# Script Description: Resets local main to remote main and updates the specific branches.
# Reads a configuration file (.config) for branch names, user details, and more.

# Set bash options
set -o errexit    # exit on error
set -o errtrace   # trap errors in functions
set -o functrace  # trap errors in functions
set -o nounset    # exit on undefined variable
set -o pipefail   # exit on fail of any command in a pipe

# Unused options
# set -o posix    # more strict parsing
# set -u          # exit on undefined variable (alternative to nounset)
# set -x          # echo commands

# Register trap commands
trap 'exit_handler ${LINENO} "$BASH_COMMAND"' ERR

# Exit codes and their descriptions
declare -A EXIT_MESSAGES
EXIT_MESSAGES=(
    [0]="Script completed successfully."
    [1]="User aborted the script."
    [2]="Usage error."
    [3]="Copy error."
    [4]="Remove error."
    [5]="Navigation error."
    [6]="Mkdir error."
    [7]="CD error."
    [8]="Branch error."
    [9]="Git config error."
    [10]="Git main error."
    [11]="Git create branch error."
    [12]="Git delete branch error."
    [13]="Git checkout error."
    [14]="Git stash error."
    [15]="Git push error."
    [16]="Git add error."
    [17]="Git commit error."
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
    if [ "$exit_code" -ne 0 ]; then
        log_entry "Error on line $line_num: $cmd"
        log_entry "${EXIT_MESSAGES[$exit_code]}"
        log_entry "exit $exit_code"
    else
        log_entry "Script completed successfully."
    fi
    exit "$exit_code"
}

# Cleanup function
# shellcheck disable=SC2317
cleanup() {

  # Return to the original branch if different from the current branch
  current_branch=$(git rev-parse --abbrev-ref HEAD)
  if [[ "$current_branch" != "$ORIG_BRANCH" ]]; then
    if ! git checkout "$ORIG_BRANCH"; then
      exit_handler "${LINE_NO}" "Error checking out $ORIG_BRANCH."
    fi
  fi

  # Return to the original git user if different from current
  current_git_user=$(git config user.name)
  if [[ "$current_git_user" != "$DEVOPS_USER" ]]; then
    if ! git config user.name "$DEVOPS_USER"; then
      exit_handler "${LINENO}" "Error setting git user.name to $DEVOPS_USER."
    fi
    if ! git config user.email "$DEVOPS_EMAIL"; then
      exit_handler "${LINENO}" "Error setting git user.email to $DEVOPS_EMAIL."
    fi
  fi

  # Pop changes from the original stash if they exist
  if git stash list | grep -q "stash@{0}"; then
    if ! git stash pop; then
      exit_handler ${LINENO} "Error popping original stash."
    fi
  fi
}

# Read .config file
mapfile -t CONFIG_VALUES < <(grep -vE '^#|^[[:space:]]*$' .config)
if [ ${#CONFIG_VALUES[@]} -eq 0 ]; then
  exit_handler ${LINENO} "Error reading .config file."
fi

# Set c
onstants
CUR_DIR="$(dirname "$0")"
DEVOPS_USER="${CONFIG_VALUES[0]}"
DEVOPS_EMAIL="${CONFIG_VALUES[1]}"
EXPECTED_DIR="${CONFIG_VALUES[3]}"
BRANCHES=("${CONFIG_VALUES[4]}" "${CONFIG_VALUES[5]}" "${CONFIG_VALUES[6]}" "${CONFIG_VALUES[7]}")

# Set warning message
WARNING=$(cat << EOM
WARNING:
Executing $0 will replace the local ${BRANCHES[3]} with remote ${BRANCHES[3]}.
It will reset the ${BRANCHES[0]}, ${BRANCHES[1]}, and ${BRANCHES[2]} branches both locally and remotely.
Parameters are read from: $CUR_DIR/.config
CAUTION: This can lead to loss of unsaved work. Consider backups before executing.
USAGE: $0
EOM
)

# Issue warning and parse user response
echo "$WARNING"
echo && read -r -p "CONTINUE ??? [yes/no] " response
responses=("y" "Y" "yes" "YES" "Yes")
if [[ ! "${responses[*]}" =~ $response ]]; then
    exit_handler ${LINENO} "User aborted the script."
fi
echo

# Ensure we're in the correct directory
if [[ "$(pwd)" != *"$EXPECTED_DIR" ]]; then
    exit_handler ${LINENO} "Please run from $EXPECTED_DIR."
fi

# Move to root directory
cd ../.. || { exit_handler ${LINENO} "Navigation error."; }

# Set Git User
git config user.name "$DEVOPS_USER" || { exit_handler ${LINENO} "Git config user.name error."; }
git config user.email "$DEVOPS_EMAIL" || { exit_handler ${LINENO} "Git config user.email error."; }

# Ensure we're on the main branch
git checkout "${BRANCHES[3]}" || { exit_handler ${LINENO} "Checkout main error."; }
git stash || { exit_handler ${LINENO} "Stash error on main."; }

# Reset main branch to mirror remote
git fetch origin || { exit_handler ${LINENO} "Git fetch error."; }
git reset --hard origin/main || { exit_handler ${LINENO} "Git reset error."; }

# Recreate each code- branch
for branch in "${BRANCHES[@]:0:3}"; do
    # Checkout, stash and delete local branch
    if git show-ref --verify --quiet "refs/heads/$branch"; then
        git checkout "$branch" || { exit_handler ${LINENO} "Checkout $branch error."; }
        git stash || { exit_handler ${LINENO} "Stash error on $branch."; }
        git checkout "${BRANCHES[3]}" || { exit_handler ${LINENO} "Checkout main error."; }
        git branch -D "$branch" || { exit_handler ${LINENO} "Deleting branch $branch error."; }
    fi

    # Delete remote branch if it exists
    if git ls-remote --heads origin "$branch" | grep -sw "$branch" >/dev/null; then
        git push origin --delete "$branch" || { exit_handler ${LINENO} "Deleting remote branch $branch error."; }
    else
        log_entry "Remote branch $branch does not exist. Skipping deletion."
    fi

    # Create a new branch from main
    git checkout -b "$branch" || { exit_handler ${LINENO} "Error creating branch $branch."; }

    # Debug info
    log_entry "Current branch: $(git branch --show-current)"
    log_entry "Current directory: $(pwd)"

    # Create toolbox directory
    mkdir -p toolbox || { exit_handler ${LINENO} "Error creating toolbox."; }

    # Confirm the required scripts directory exists and has content before copying
    env_name="${branch#code-}"
    if [[ -d "scripts/$env_name/" && $(ls -A "scripts/$env_name/") ]]; then
        cp -r "scripts/$env_name/"* toolbox/ || { exit_handler ${LINENO} "Error copying scripts to toolbox."; }
    else
        log_entry "Directory scripts/$env_name/ does not exist or is empty."
    fi

    # Cleanup directories based on branch
    case "$branch" in
        "${BRANCHES[0]}") rm -rf staging production > /dev/null 2>&1 || { exit_handler ${LINENO} "Error removing directories from ${BRANCHES[0]}."; } ;;
        "${BRANCHES[1]}") rm -rf production > /dev/null 2>&1 || { exit_handler ${LINENO} "Error removing directories from ${BRANCHES[1]}."; } ;;
        "${BRANCHES[2]}") rm -rf development > /dev/null 2>&1 || { exit_handler ${LINENO} "Error removing directories from ${BRANCHES[2]}."; } ;;
    esac

    # Remove scripts
    rm -rf scripts || { exit_handler ${LINENO} "Error removing scripts."; }
    rm -rf .github/workflows || { exit_handler ${LINENO} "Error removing .github/workflows."; }

    # Add, commit, and push to remote
    git add . || { exit_handler ${LINENO} "Git add error."; }
    git commit -m "Updated $branch from main [skip ci]" || { exit_handler ${LINENO} "Git commit error."; }
    git push -u origin "$branch" || { exit_handler ${LINENO} "Git push error."; }
done

# Final steps
git checkout "${BRANCHES[3]}" || { exit_handler ${LINENO} "Checkout main error."; }
# Check if there are stashes to drop
if git stash list | grep -q 'stash@'; then
    git stash drop || { exit_handler ${LINENO} "Stash drop error."; }
fi

# Navigate back to original directory
cd "$CUR_DIR" || { exit_handler ${LINENO} "Error navigating back to $CUR_DIR."; }

# Completion message
log_entry "$0 finished."
exit 0
