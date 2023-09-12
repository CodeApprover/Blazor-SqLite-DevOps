#!/bin/bash

# Script Description: Resets local main to remote main and updates the specific branches.
# Reads a configuration file (.config) for branch names, user details, and more.

# Set bash options
set -o errexit  # exit on error
set -o errtrace   # trap errors in functions
set -o functrace  # trap errors in functions
set -o nounset  # exit on undefined variable
set -o pipefail   # exit on fail of any command in a pipe

# Unused options
# set -o posix  # more strict parsing
# set -u      # exit on undefined variable (alternative to nounset)
# set -x      # echo commands

# Register trap commands
trap 'exit_handler $? ${LINENO}' ERR
trap cleanup EXIT

# Exit codes and their descriptions
declare -A EXIT_MESSAGES
EXIT_MESSAGES=(
  [0]="Script completed successfully."
  [1]="Error reading .config file."
  [2]="User aborted the script."
  [3]="$0 must be run from its own directory."
  [4]="Directory navigation error."
  [5]="Git user config name error."
  [6]="Git user config email error."
  [7]="Git checkout error on main."
  [8]="Git make stash error on main."
  [9]="Git fetch error on main."
  [10]="Git reset error on main."
  [11]="Git checkout code- branch error."
  [12]="Git stash error on branch."
  [13]="Git delete error on local code- branch"
  [14]="Git delete error on remote code- branch"
  [15]="Git crete error for local code- branch."
  [16]="Error creating toolbox dir in code- branch."
  [17]="Error copying files to toolbox dir in code- branch."
  [18]="Error removing excess directories from code- branch."
  [19]="Git add error for remote code- branch."
  [20]="Git commit error for remote code- branch."
  [21]="Git push error for remote code- branch."
  [22]="Git stash drop error for local code- branch."
  [23]="Git stash pop error for main."
)

# Logging function
log_entry() {
  local message="$1"
  echo "$(date +'%Y-%m-%d %H:%M:%S') - $message"
}

# Exit handler function
exit_handler() {
  local exit_code="$1"
  local line_num="$2"
  log_entry "Exited $0 -> line $line_num -> exit code $exit_code"

  if [ "$exit_code" -ne 0 ] && [ -n "${EXIT_MESSAGES[$exit_code]}" ]; then
    log_entry "${EXIT_MESSAGES[$exit_code]}"
  elif [ "$exit_code" -eq 0 ]; then
    log_entry "Script completed successfully."
  else
    log_entry "Unknown error. exit $exit_code"
  fi
  exit "$exit_code"
}

# Cleanup function
# shellcheck disable=SC2317
cleanup() {

  # Return to the original branch if different from the current branch
  current_branch=$(git rev-parse --abbrev-ref HEAD)
  if [[ "$current_branch" != "${BRANCHES[3]}" ]]; then
    if ! git checkout "${BRANCHES[3]}"; then
      exit_handler 7 "${LINE_NO}"
    fi
  fi

  # Return to the original git user if different from current
  current_git_user=$(git config user.name)
  if [[ "$current_git_user" != "$DEVOPS_USER" ]]; then
    if ! git config user.name "$DEVOPS_USER"; then
      exit_handler 5 "${LINENO}"
    fi
    if ! git config user.email "$DEVOPS_EMAIL"; then
      exit_handler 6 "${LINENO}"
    fi
  fi

  # Pop changes from the original stash if they exist
  if git stash list | grep -q "stash@{0}"; then
    if ! git stash pop; then
      exit_handler 23 "${LINENO}"
    fi
  fi
}

# Read .config file
mapfile -t CONFIG_VALUES < <(grep -vE '^#|^[[:space:]]*$' .config)
if [ ${#CONFIG_VALUES[@]} -eq 0 ]; then
  exit_handler 1 "${LINENO}"
fi

# Set constants
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
  exit_handler 2 "${LINENO}"
fi
echo

# Ensure we're in the correct directory
if [[ "$(pwd)" != *"$EXPECTED_DIR" ]]; then
  exit_handler 3 "${LINENO}"
fi

# Move to root directory
cd ../.. || { exit_handler 4 "${LINENO}"; }

# Set Git User
git config user.name "$DEVOPS_USER" || { exit_handler 5 "${LINENO}"; }
git config user.email "$DEVOPS_EMAIL" || { exit_handler 6 "${LINENO}"; }

# Ensure we're on the main branch
git checkout "${BRANCHES[3]}" || { exit_handler 7 "${LINENO}"; }
git stash || { exit_handler 8 "${LINENO}"; }

# Reset main branch to mirror remote
git fetch origin || { exit_handler 9 "${LINENO}"; }
git reset --hard origin/main || { exit_handler 10 "${LINENO}"; }

# Recreate each code- branch
for branch in "${BRANCHES[@]:0:3}"; do
  # Checkout, stash and delete local branch
  if git show-ref --verify --quiet "refs/heads/$branch"; then
    git checkout "$branch" || { exit_handler 11 "${LINENO}"; }
    git stash || { exit_handler 12 "${LINENO}"; }
    git checkout "${BRANCHES[3]}" || { exit_handler 7 "${LINENO}"; }
    git branch -D "$branch" || { exit_handler 13 "${LINENO}"; }
  fi

  # Delete remote branch if it exists
  if git ls-remote --heads origin "$branch" | grep -sw "$branch" >/dev/null; then
    git push origin --delete "$branch" || { exit_handler 14 "${LINENO}"; }
  else
    log_entry "Remote branch $branch does not exist. Skipping deletion."
  fi

  # Create a new branch from main
  git checkout -b "$branch" || { exit_handler 15 "${LINENO}"; }

  # Debug info
  log_entry "Current branch: $(git branch --show-current)"
  log_entry "Current directory: $(pwd)"

  # Create toolbox directory
  mkdir -p toolbox || { exit_handler 16 ${LINENO}; }

  # Confirm the required scripts directory exists and has content before copying
  env_name="${branch#code-}"
  if [[ -d "scripts/$env_name/" && $(ls -A "scripts/$env_name/") ]]; then
    cp -r "scripts/$env_name/"* toolbox/ || { exit_handler 17 ${LINENO}; }
  else
    log_entry "Directory scripts/$env_name/ does not exist or is empty."
  fi

  # Cleanup directories based on branch
  case "$branch" in
    "${BRANCHES[0]}") rm -rf staging production > /dev/null 2>&1 || { exit_handler 18  "${LINENO}"; } ;;
    "${BRANCHES[1]}") rm -rf production > /dev/null 2>&1 || { exit_handler 18 "${LINENO}"; } ;;
    "${BRANCHES[2]}") rm -rf development > /dev/null 2>&1 || { exit_handler 18 "${LINENO}"; } ;;
  esac

  # Remove scripts
  rm -rf scripts || { exit_handler 18 "${LINENO}"; }
  rm -rf .github/workflows || { exit_handler 18 "${LINENO}"; }

  # Add, commit, and push to remote
  git add . || { exit_handler 19 "${LINENO}"; }
  git commit -m "Updated $branch from main [skip ci]" || { exit_handler 20 "${LINENO}"; }
  git push -u origin "$branch" || { exit_handler 21 "${LINENO}"; }
done

# Final steps
git checkout "${BRANCHES[3]}" || { exit_handler 7 "${LINENO}"; }
# Check if there are stashes to drop
if git stash list | grep -q 'stash@'; then
  git stash drop || { exit_handler 22 "${LINENO}"; }
fi

# Navigate back to original directory
cd "$CUR_DIR" || { exit_handler 4 "${LINENO}"; }

# Successful completion
log_entry "$0 completed successfully."
exit_handler 0 "${LINENO}"

# EOF