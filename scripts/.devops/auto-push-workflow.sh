#!/bin/bash

# Script Description: Automates commits and pushes to specified branches with optional intervals.
# Reads user and configuration details from a .config file.

#!/bin/bash

# Set bash options
set -o errexit  # exit on error
set -o errtrace   # trap errors in functions
set -o functrace  # trap errors in functions
set -o nounset  # exit on undefined variable
set -o pipefail   # exit on fail of any command in a pipe

# Register trap commands
trap 'exit_handler $? ${LINENO}' ERR
trap cleanup EXIT

# Set constants
CUR_DIR="$(dirname "$0")"
ORIG_BRANCH=$(git rev-parse --abbrev-ref HEAD)

# Exit codes and their descriptions
declare -A EXIT_MESSAGES
EXIT_MESSAGES=(
  [0]="Script completed successfully."
  [1]="User aborted the script."
  [2]="$0 must be run from its own directory."
  [3]="Invalid parameters provided."
  [4]="Invalid branch name."
  [5]="Invalid iteration count."
  [6]="Invalid wait duration."
  [7]="No file at the specified CSPROJ location."
  [8]="Git config user.name failure."
  [9]="Git config user.email failure."
  [10]="Git stash error for the current branch."
  [11]="Git checkout error for the branch."
  [12]="Git stash error for the branch."
  [13]="Git add error."
  [14]="Git commit error."
  [15]="Git push error."
  [16]="Git stash pop error for the branch."
  [17]="Git checkout error for the original branch."
  [18]="Git stash pop error for the original branch."
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
  if [[ "$current_branch" != "${BRANCHES[0]}" ]]; then
    if ! git checkout "${BRANCHES[0]}"; then
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
  log_entry "Error reading .config file."
  exit_handler 3 "${LINENO}"
fi

# Set Constants from .config file
DEVOPS_USER="${CONFIG_VALUES[0]}"
DEVOPS_EMAIL="${CONFIG_VALUES[1]}"
EXPECTED_DIR="${CONFIG_VALUES[3]}"
BRANCHES=("${CONFIG_VALUES[4]}" "${CONFIG_VALUES[5]}" "${CONFIG_VALUES[6]}" "${CONFIG_VALUES[7]}")
MAX_SECS_WAIT="${CONFIG_VALUES[8]}"
MAX_PUSHES="${CONFIG_VALUES[9]}"

# Set user info
declare -A USER_INFO
USER_INFO=(
  ["${BRANCHES[0]}"]="${CONFIG_VALUES[16]} ${CONFIG_VALUES[17]}"
  ["${BRANCHES[1]}"]="${CONFIG_VALUES[10]} ${CONFIG_VALUES[11]}"
  ["${BRANCHES[2]}"]="${CONFIG_VALUES[12]} ${CONFIG_VALUES[13]}"
  ["${BRANCHES[3]}"]="${CONFIG_VALUES[14]} ${CONFIG_VALUES[15]}"

)

# Set usage message
USAGE=$(cat << EOM
Usage:  $0 <branch-name>  <number-of-pushes>  <wait-seconds>
Example:  $0 ${BRANCHES[0]} 3 600

Branches: ${BRANCHES[0]} ${BRANCHES[1]} ${BRANCHES[2]}
Branch parameter is mandatory.
Number of pushes is optional, default is 1, max is $MAX_PUSHES.
Wait seconds is optional, default is 0, max is $MAX_SECS_WAIT seconds.
EOM
)

# Set warning message
WARNING=$(cat << EOM
WARNING: You are about to execute $0
This script makes commits and pushes them to a specified branch.

PARAMETERS:  <branch-name>  <number-of-pushes>  <wait-seconds>

1.  Mandatory First parameter (string) 'branch-name' must be one of:
  ${BRANCHES[0]}  ${BRANCHES[1]}  ${BRANCHES[2]}

2.  Optional Second parameter (int) sets the number of pushes
  (default is 1, max is $MAX_PUSHES).

3.  Optional Third parameter (int) sets the interval in seconds between pushes
  (default is 0, max is $MAX_SECS_WAIT seconds).

GIT USERS: The script presumes authourisation for DevOps git user:
  ${USER_INFO[${BRANCHES[3]}]}

CAUTION: Consider making a backup before execution.
  Note: This script stashes and pops any stashes (if created)
  to restore any changes in the current branch.
EOM
)

# Issue warning and parse user response
echo "$WARNING"
echo && read -r -p "CONTINUE ??? [yes/no] " response
responses=("y" "Y" "yes" "YES" "Yes")
if [[ ! "${responses[*]}" =~ $response ]]; then
  exit_handler 1 "${LINENO}"
fi
echo

# Check script is running from correct directory
if [[ "$(pwd)" != *"$EXPECTED_DIR" ]]; then
  log_entry "Error: Please run this script from within its own directory ($EXPECTED_DIR/)."
  exit_handler 2 "${LINENO}"
fi

# Check for mandatory branch parameter
if [[ -z "${1:-}" ]]; then
  log_entry "Error: No branch specified."
  echo "$USAGE"
  exit_handler 3 "${LINENO}"
fi

# Validate provided branch parameter
branch="$1"
if [[ ! " ${BRANCHES[*]} " =~ ${branch} ]]; then
  log_entry "Error: Invalid branch name provided."
  echo "$USAGE"
  exit_handler 4 "${LINENO}"
fi

# Validate provided iteration count
iteration_count="${2:-1}" # default to 1 if not provided
if ! [[ "$iteration_count" =~ ^[0-9]+$ ]] || [ "$iteration_count" -lt 1 ] || [ "$iteration_count" -gt "$MAX_PUSHES" ]; then
  log_entry "Error: Invalid iteration count."
  echo "$USAGE"
  exit_handler 5 "${LINENO}"
fi

# Validate provided wait duration
wait_duration="${3:-0}" # default to 0 if not provided
if ! [[ "$wait_duration" =~ ^[0-9]+$ ]] || [ "$wait_duration" -lt 0 ] || [ "$wait_duration" -gt "$MAX_SECS_WAIT" ]; then
  log_entry "Error: Invalid wait duration."
  echo "$USAGE"
  exit_handler 6 "${LINENO}"
fi

# Main loop to execute commit and push
for (( i=0; i<$iteration_count; i++ )); do

  # Stash any changes in current branch
  if ! git stash save --keep-index --include-untracked "auto-commit-stash-$i"; then
    exit_handler 10 "${LINENO}"
  fi

  # Switch to the target branch
  if ! git checkout "$branch"; then
    exit_handler 11 "${LINENO}"
  fi

  # Add changes
  if ! git add .; then
    exit_handler 13 "${LINENO}"
  fi

  # Commit changes
  commit_msg="Automated commit #$i"
  if ! git commit -m "$commit_msg"; then
    exit_handler 14 "${LINENO}"
  fi

  # Push changes
  if ! git push origin "$branch"; then
    exit_handler 15 "${LINENO}"
  fi

  # Switch back to original branch and pop the stash
  if ! git checkout "$ORIG_BRANCH"; then
    exit_handler 17 "${LINENO}"
  fi
  if ! git stash pop; then
    exit_handler 18 "${LINENO}"
  fi

  # Wait for the specified duration before the next iteration
  if [ "$i" -lt "$((iteration_count - 1))" ]; then # If not the last iteration
    sleep "$wait_duration"
  fi

done

# Successful completion
exit_handler 0 "${LINENO}"

# EOF