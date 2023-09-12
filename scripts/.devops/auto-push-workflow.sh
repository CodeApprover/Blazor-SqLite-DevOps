#!/bin/bash

# Script Description: Automates commits and pushes to a specified branch with optional intervals.
# Reads user and configuration details from a .config file.

# Set bash options
set -o errexit      # exit on error
set -o errtrace     # trap errors in functions
set -o functrace    # trap errors in functions
set -o nounset      # exit on undefined variable
set -o pipefail     # exit on fail of any command in a pipe

# Unused options
# set -o posix      # more strict parsing
# set -u            # exit on undefined variable (alternative to nounset)
# set -x            # echo commands

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
  [8]="Branch name parameter required."
  [9]="Branch name invalid."
  [10]="Invalid number of pushes."
  [11]="Invalid wait seconds."
  [12]="Dotnet .csproj file not found."
  [13]="Git add error."
  [14]="Git commit error."
  [15]="Git push error."
  [16]="Git stash pop error for the branch."
  [17]="Git checkout error for the original branch."
  [18]="Git stash pop error for the original branch."
  [19]="Git stash pop error for main branch."
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

  # Return to the main branch if different from the current branch
  current_branch=$(git rev-parse --abbrev-ref HEAD)
  if [[ "$current_branch" != "${BRANCHES[0]}" ]]; then
    if ! git checkout "${BRANCHES[0]}"; then
      exit_handler 7 "${LINE_NO}"
    fi
  fi

  # Return to the main git user if different from current
  current_git_user=$(git config user.name)
  if [[ "$current_git_user" != "$DEVOPS_USER" ]]; then
    if ! git config user.name "$DEVOPS_USER"; then
      exit_handler 5 "${LINENO}"
    fi
    if ! git config user.email "$DEVOPS_EMAIL"; then
      exit_handler 6 "${LINENO}"
    fi
  fi

  # Pop changes from the main stash if they exist
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
  ["${BRANCHES[0]}"]="${CONFIG_VALUES[16]} ${CONFIG_VALUES[17]}" # main
  ["${BRANCHES[1]}"]="${CONFIG_VALUES[10]} ${CONFIG_VALUES[11]}" # code-development
  ["${BRANCHES[2]}"]="${CONFIG_VALUES[12]} ${CONFIG_VALUES[13]}" # code-staging
  ["${BRANCHES[3]}"]="${CONFIG_VALUES[14]} ${CONFIG_VALUES[15]}" # code-production
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
WARNING:
Executing $0 makes commits and pushes them to a specified branch.
Some parameters are read from: .config

PARAMETERS: <branch-name>  <number-of-pushes>  <wait-seconds>

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

USAGE:
  $USAGE
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
CUR_DIR="$(dirname "$0")"
cd ../.. || { exit_handler 4 "${LINENO}"; }

# Check for mandatory branch parameter
if [[ -z "${1:-}" ]]; then
  echo "$USAGE"
  exit_handler 8 "${LINENO}"
fi

# Validate provided branch parameter
branch="$1"
if [[ ! " ${BRANCHES[*]} " =~ ${branch} ]]; then
  echo "$USAGE"
  exit_handler 9 "${LINENO}"
fi

# Validate provided iteration count
num_pushes="${2:-1}" # default 1 push
if ! [[ "$num_pushes" =~ ^[0-9]+$ ]] || [ "$num_pushes" -lt 1 ] || [ "$num_pushes" -gt "$MAX_PUSHES" ]; then
  echo "$USAGE"
  exit_handler 10 "${LINENO}"
fi

# Validate provided wait duration
wait_seconds="${3:-0}" # default 0 seconds
if ! [[ "$wait_seconds" =~ ^[0-9]+$ ]] || [ "$wait_seconds" -lt 0 ] || [ "$wait_seconds" -gt "$MAX_SECS_WAIT" ]; then
  echo "$USAGE"
  exit_handler 11 "${LINENO}"
fi

# Set environment and csproj file
env="${branch#code-}"
CSPROJ="./$env/$PROJ_NAME/$PROJ_NAME.csproj"
if [ ! -f "$CSPROJ" ]; then
  exit_handler 12 "${LINENO}"
fi

# Main loop to execute commit and push
# Set workflow driver file
DRIVER="./$env/$PROJ_NAME/workflow.driver"
[ ! -f "$DRIVER" ] && touch "$DRIVER"

# Git add, commit and push in a loop.
for i in $(seq 1 "$num_pushes"); do
  # Set commit message
  commit_msg="DevOps test push $i of $num_pushes to $branch"

  # Set workflow.driver file
  echo "
  Push Iteration: $i of $num_pushes
  Commit Message: $commit_msg
  Wait Interval:  $wait_seconds seconds
  Target Branch:  $branch
  Environment:    $env
  Driver:         $DRIVER
  Csproj:         $CSPROJ
  DevOps User:    $DEVOPS_USER
  DevOps Email:   $DEVOPS_EMAIL
  Date:           $(date +'%Y-%m-%d %H:%M:%S')
  " > "$DRIVER"

  # git add
  git add -A || {
    log_entry "Git add error for $branch commit $i of $num_pushes"
    exit_handler 13 "${LINE_NO}"
  }

  # git commit
  git commit -m "$commit_msg" || {
    log_entry "Git commit error for $branch commit $i of $num_pushes"
    exit_handler 14 "${LINE_NO}"
  }

  # git push
  git push || {
    log_entry "Git push error for $branch push $i of $num_pushes"
    exit_handler 15 "${LINE_NO}"
  }

  # Display driver file
  cat "$DRIVER" && echo

  # Wait if required
  if [ "$i" -lt "$num_pushes" ]; then
    log_entry "Starting countdown for $wait_seconds seconds..."
    for (( counter=wait_seconds; counter>0; counter-- )); do
      printf "\rWaiting... %02d seconds remaining" "$counter"
      sleep 1
    done
    echo ""  # Move to a new line after countdown completes
  fi

done

# Checkout the main branch
git checkout "${BRANCHES[0]}" || { exit_handler 7 "${LINENO}"; }

# Pop changes from the main stash if they exist
if git stash list | grep -q "stash@{0}"; then
  if ! git stash pop; then
    exit_handler 23 "${LINENO}"
  fi
fi

# Navigate back to original directory
cd "$CUR_DIR" || { exit_handler 4 "${LINENO}"; }

# Successful completion
exit_handler 0 "${LINENO}"

# EOF