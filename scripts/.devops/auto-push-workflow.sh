#!/bin/bash

# Script Description: Automates commits and pushes to a specified branch with optional intervals.
# Reads user and configuration details from a .config file.

set -o errexit  # exit on error
set -o nounset  # exit on undefined variable
set -o pipefail # exit on fail of any command in a pipe
# set -x        # echo commands

# Register trap commands
trap 'exit_handler $? ${LINENO}' ERR
trap cleanup EXIT

# Exit codes and their descriptions
declare -A EXIT_MESSAGES
EXIT_MESSAGES=(
    [0]="Script completed successfully."
    [1]="JQ not installed."
    [2]="Error locating JSON config file."
    [3]="Error incorrect JSON config file."
    [4]="User aborted the script."
    [5]="$0 must be run from its own directory."
    [6]="Directory navigation error."
    [7]="Git user config name error."
    [8]="Git user config email error."
    [9]="Git checkout error on main branch."
    [10]="Branch name parameter required."
    [11]="Branch name invalid."
    [12]="Invalid number of pushes."
    [13]="Invalid wait seconds."
    [14]="Dotnet .csproj file not found."
    [15]="Git add error for the code- branch."
    [16]="Git commit error for the code- branch."
    [17]="Git push error for the code- branch."
    [18]="Git stash pop error for the code- branch."
    [19]="Git stash pop error for main branch."
    [20]="Git checkout error for the code- branch."
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
    log_entry "Exited $0 -> line $line_num"
    log_entry "exit code $exit_code"
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
    if [[ "$current_branch" != "main" ]]; then
        if ! git checkout main; then
            exit_handler 9 "${LINE_NO}"
        fi
    fi

    # Set Devops git user if different from current
    current_git_user=$(git config user.name)
    if [[ -n "$DEVOPS_USER" ]]; then
        if [[ "$current_git_user" != "$DEVOPS_USER" ]]; then
            if ! git config user.name "$DEVOPS_USER"; then
                exit_handler 7 "${LINENO}"
            fi
            if ! git config user.email "$DEVOPS_EMAIL"; then
                exit_handler 8 "${LINENO}"
            fi
        fi
    fi
}

# Check if JQ is installed
if ! command -v jq &> /dev/null; then
    exit_handler 1 "${LINENO}"
fi

# Check if the JSON file exists
if [[ ! -e "config.json" ]]; then
    exit_handler 2 "${LINENO}"
fi

# Load the JSON config
JSON_CONFIG=$(cat config.json)

# Ensure JSON is valid
if ! jq empty <<< "$JSON_CONFIG" &>/dev/null; then
  exit_handler 3 "${LINENO}"
fi

# Extract constants from json
JSON_CONFIG=$(<config.json)
DEVOPS_USER=$(echo "$JSON_CONFIG" | jq -r '.DevOpsUser.name')
DEVOPS_EMAIL=$(echo "$JSON_CONFIG" | jq -r '.DevOpsUser.email')
PROJ_NAME=$(echo "$JSON_CONFIG" | jq -r '.ProjectConfig.name')
EXPECTED_DIR=$(echo "$JSON_CONFIG" | jq -r '.ProjectConfig.dir')
MAX_SECS_WAIT=$(echo "$JSON_CONFIG" | jq -r '.MaxConfig.wait')
MAX_PUSHES=$(echo "$JSON_CONFIG" | jq -r '.MaxConfig.retries')

# Define branches (json must match)
BRANCHES=("code-development" "code-staging" "code-production")

# Extract user names and emails from json
declare -A USER_INFO
for branch in "${BRANCHES[@]}"; do
  USER_NAME=$(echo "$JSON_CONFIG" | jq -r ".Users[\"$branch\"].name")
  USER_EMAIL=$(echo "$JSON_CONFIG" | jq -r ".Users[\"$branch\"].email")
  # Check values for defined branch
  if [ -z "$USER_NAME" ] || [ -z "$USER_EMAIL" ]; then
  exit_handler 3 "${LINENO}"
  fi
  USER_INFO["$branch"]="${USER_NAME},${USER_EMAIL}"
done

# Verify user info for each branch
for branch in "${BRANCHES[@]}"; do
    IFS=',' read -ra USER_DETAILS <<< "${USER_INFO[$branch]}"
    if [ -z "${USER_DETAILS[0]}" ] || [ -z "${USER_DETAILS[1]}" ]; then
        exit_handler 3 "${LINENO}"
    fi
done

# Set warning message
WARNING=$(cat << EOM
WARNING:

Executing $0 makes commits and pushes them to a specified branch.
Note: Some parameters are read from: config.json

USAGE:    $0 <branch-name>  <number-of-pushes>  <wait-seconds>

EXAMPLE:  $0 ${BRANCHES[0]} 3 600

PARAMETERS: <branch-name>  <number-of-pushes>  <wait-seconds>

1. Mandatory First parameter (string) 'branch-name' must be one of:
   ${BRANCHES[0]} | ${BRANCHES[1]} | ${BRANCHES[2]}

2. Optional Second parameter (int) sets the number of pushes
   (default is 1, max is $MAX_PUSHES).

3. Optional Third parameter (int) sets the interval in seconds between pushes
   (default is 0, max is $MAX_SECS_WAIT seconds).

GIT USERS: The script presumes authourisation for DevOps git user:
   $DEVOPS_USER ($DEVOPS_EMAIL)

CAUTION: Consider making a backup before execution.
  Note: This script stashes and pops any stashes (if created)
  to restore any changes in the current branch.

EOM
)

# Ensure we're in the correct directory
if [[ "$(pwd)" != *"$EXPECTED_DIR" ]]; then
  exit_handler 5 "${LINENO}"
fi

# Issue warning and parse user response
echo "$WARNING"
echo && read -r -p "CONTINUE ??? [yes/no] " response
responses=("y" "Y" "yes" "YES" "Yes")
if [[ ! "${responses[*]}" =~ $response ]]; then
  exit_handler 4 "${LINENO}"
fi
echo

# Navigate to root directory
CUR_DIR="$(dirname "$0")"
cd ../.. || { exit_handler 6 "${LINENO}"; }

# Check for mandatory branch parameter
if [[ -z "${1:-}" ]]; then
  exit_handler 10 "${LINENO}"
fi

# Validate provided branch parameter
branch="$1"
if [[ ! " ${BRANCHES[*]} " =~ ${branch} ]]; then
  exit_handler 11 "${LINENO}"
fi

# Validate provided iteration count
num_pushes="${2:-1}" # default 1 push
if ! [[ "$num_pushes" =~ ^[0-9]+$ ]] || [ "$num_pushes" -lt 1 ] || [ "$num_pushes" -gt "$MAX_PUSHES" ]; then
  exit_handler 12 "${LINENO}"
fi

# Validate provided wait duration
wait_seconds="${3:-0}" # default 0 seconds
if ! [[ "$wait_seconds" =~ ^[0-9]+$ ]] || [ "$wait_seconds" -lt 0 ] || [ "$wait_seconds" -gt "$MAX_SECS_WAIT" ]; then
  exit_handler 13 "${LINENO}"
fi

# Set environment
env="${branch#code-}"

# Validate csproj file
CSPROJ="./$env/$PROJ_NAME/$PROJ_NAME.csproj"
if [ ! -f "$CSPROJ" ]; then
  exit_handler 14 "${LINENO}"
fi

# Set DevOps user name
if ! git config user.name "$DEVOPS_USER"; then
  exit_handler 7 "${LINENO}"
fi

# Set DevOps email
if ! git config user.email "$DEVOPS_EMAIL"; then
  exit_handler 8 "${LINENO}"
fi

# Checkout main to ensure we start from main
git checkout main || { exit_handler 9 "${LINENO}"; }

# Checkout the specified required branch
git checkout "$branch" || { exit_handler 20 "${LINENO}"; }

# Set workflow driver file
DRIVER="./$env/$PROJ_NAME/workflow.driver"
[ ! -f "$DRIVER" ] && touch "$DRIVER"

# Set user info for the required branch
IFS=',' read -ra USER_DETAILS <<< "${USER_INFO[$branch]}"
if [ -z "${USER_DETAILS[0]}" ] || [ -z "${USER_DETAILS[1]}" ]; then
  exit_handler 3 "${LINENO}"
fi
BRANCH_USER="${USER_DETAILS[0]}"
BRANCH_EMAIL="${USER_DETAILS[1]}"

# Switch Git user if different from DevOps user
if [[ "$BRANCH_USER" != "$DEVOPS_USER" ]]; then
  # Set Git user name for the branch
  if ! git config user.name "$BRANCH_USER"; then
  exit_handler 7 "${LINENO}"
  fi

  # Set Git email for the branch
  if ! git config user.email "$BRANCH_EMAIL"; then
  exit_handler 8 "${LINENO}"
  fi
fi

# Stash the branch if it has changes
if ! git diff --quiet; then
  if ! git stash push -u -m "Stash for devops script operations on $branch"; then
  exit_handler 18 "${LINENO}"
  fi
fi

########################################
# Git add, commit, push in a loop
########################################

for i in $(seq 1 "$num_pushes"); do

  # Set commit message
  commit_msg="DevOps test push $i of $num_pushes to $branch"

  # Set workflow.driver file
  echo "
Push Iteration: $i of $num_pushes
Commit Message: $commit_msg
Wait Interval:  $wait_seconds seconds
Target Branch:  $branch
Environment:  $env
Driver:     $DRIVER
Csproj:     $CSPROJ
DevOps User:  $DEVOPS_USER
DevOps Email:   $DEVOPS_EMAIL
Date:       $(date +'%Y-%m-%d %H:%M:%S')
" > "$DRIVER"

  # git add
  git add -A || { exit_handler 15 "${LINE_NO}"; }

  # git commit
  git commit -m "$commit_msg" || { exit_handler 16 "${LINE_NO}"; }

  # git push
  git push || { exit_handler 17 "${LINE_NO}"; }

  # Display driver file
  cat "$DRIVER" && echo

  # Wait if required
  if [ "$i" -lt "$num_pushes" ]; then
  log_entry "Starting countdown for $wait_seconds seconds..."
  for (( counter=wait_seconds; counter>0; counter-- )); do
    printf "\rWaiting... %02d seconds remaining" "$counter"
    sleep 1
  done
  echo ""  # reset countdown newline
  fi

done

# Pop changes from the branch stash if they exist
if git stash list | grep -q "stash@{0}"; then
  if ! git stash pop; then
  exit_handler 19 "${LINENO}"
  fi
fi

# Reset DevOps user name
if ! git config user.name "$DEVOPS_USER"; then
  exit_handler 7 "${LINENO}"
fi

# Reset DevOps email
if ! git config user.email "$DEVOPS_EMAIL"; then
  exit_handler 8 "${LINENO}"
fi

# Checkout the main branch
git checkout main || { exit_handler 9 "${LINENO}"; }

# Navigate back to original directory
cd "$CUR_DIR" || { exit_handler 6 "${LINENO}"; }

# Successful completion
exit_handler 0 "${LINENO}"

# EOF