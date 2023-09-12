#!/bin/bash

# Set bash options
set -o errexit      # exit on error
set -o errtrace     # trap errors in functions
set -o functrace    # trap errors in functions
set -o nounset      # exit on undefined variable
set -o pipefail     # exit on fail of any command in a pipe

# Unused bash options
# set -o posix     # more strict parsing
# set -u           # exit on undefined variable (alternative to nounset)
# set -x           # echo commands

# Register trap commands
trap cleanup EXIT
trap error_handler ERR

# Set constants
CUR_DIR="$(dirname "$0")"
ORIG_BRANCH=$(git rev-parse --abbrev-ref HEAD)

# Exit codes and their descriptions
declare -A EXIT_MESSAGES
EXIT_MESSAGES=(
    [0]="Script completed successfully."
    [1]="User aborted the script."
    [2]="Script not executed from the expected directory."
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

# Exit error function
# shellcheck disable=SC2317
error_handler() {
    local exit_code=$?
    local last_cmd="${BASH_COMMAND}"
    local script_name="${0}"  # Name of the current script
    if [ "$exit_code" -ne 0 ]; then
        log_entry "Error in script '$script_name' on line $LINENO: Last command was '$last_cmd'. ${EXIT_MESSAGES[$exit_code]}"
        log_entry "${EXIT_MESSAGES[$exit_code]}"
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
            exit 17
        fi
    fi

    # Return to the original git user if different from current
    current_git_user=$(git config user.name)
    if [[ "$current_git_user" != "$DEVOPS_USER" ]]; then
        git config user.name "$DEVOPS_USER"
        git config user.email "$DEVOPS_EMAIL"
    fi

    # Pop changes from the stash if they exist
    if git stash list | grep -q "stash@{0}"; then
        if ! git stash pop; then
          exit 18
        fi
    fi

    log_entry "Returning to original state if necessary..."
}

# Read .config file
mapfile -t CONFIG_VALUES < <(grep -vE '^#|^[[:space:]]*$' .config)
if [ ${#CONFIG_VALUES[@]} -eq 0 ]; then
    log_entry "Error reading .config file."
    exit 3
fi

# Set Constants from .config file
DEVOPS_USER="${CONFIG_VALUES[0]}"
DEVOPS_EMAIL="${CONFIG_VALUES[1]}"
PROJ_NAME="${CONFIG_VALUES[2]}"
EXPECTED_DIR="${CONFIG_VALUES[3]}"
BRANCHES=("${CONFIG_VALUES[4]}" "${CONFIG_VALUES[5]}" "${CONFIG_VALUES[6]}" "${CONFIG_VALUES[7]}")
MAX_SECS_WAIT="${CONFIG_VALUES[8]}"
MAX_PUSHES="${CONFIG_VALUES[9]}"

# Set user info
declare -A USER_INFO
USER_INFO=(
    ["${BRANCHES[0]}"]="${CONFIG_VALUES[10]} ${CONFIG_VALUES[11]}"
    ["${BRANCHES[1]}"]="${CONFIG_VALUES[12]} ${CONFIG_VALUES[13]}"
    ["${BRANCHES[2]}"]="${CONFIG_VALUES[14]} ${CONFIG_VALUES[15]}"
    ["${BRANCHES[3]}"]="${CONFIG_VALUES[16]} ${CONFIG_VALUES[17]}"
)

# Set usage message
USAGE=$(cat << EOM
Usage:   $0 branch-name (mandatory string) + pushes ( optional int) + wait_seconds ( optional int)
Example: $0 ${BRANCHES[1]} 3 600
Branch Options: ${BRANCHES[1]} ${BRANCHES[2]} ${BRANCHES[3]}
EOM
)

# Set warning message
WARNING=$(cat << EOM

WARNING: You are about to execute $0
This script makes commits and pushes them to a specified branch.

PARAMETERS: <branch-name> <number-of-pushes> <wait-seconds>

1. Mandatory First parameter (string) 'branch-name' must be one of:
   ${BRANCHES[0]}  ${BRANCHES[1]}  ${BRANCHES[2]}

2. Optional Second parameter (int) sets the number of pushes
   (default is 1, max is $MAX_PUSHES).

3. Optional Third parameter (int) sets the interval in seconds between pushes
   (default is 0, max is $MAX_SECS_WAIT seconds).

GIT USERS: The script presumes the following git users are authorised:
   ${USER_INFO[${BRANCHES[0]}]}
   ${USER_INFO[${BRANCHES[1]}]}
   ${USER_INFO[${BRANCHES[2]}]}
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
    exit 1
fi
echo

# Check script is running from correct directory
if [[ "$(pwd)" != *"$EXPECTED_DIR" ]]; then
    log_entry "Error: Please run this script from within its own directory ($EXPECTED_DIR/)."
    exit 2
fi

# Validate branch -> param 1 mandatory
branch="${1:-}"
valid_branches_string=" ${BRANCHES[*]} "

if [[ ! "$valid_branches_string" =~ ${branch} ]]; then
    log_entry "$USAGE"
    exit 4
fi

# Set iteration count and wait seconds
num_pushes="${2:-1}"  # default 1
wait_duration="${3:-0}"  # default 0

# Validate iteration count
if [[ -z "$num_pushes" || "$num_pushes" -lt 1 || "$num_pushes" -gt "$MAX_PUSHES" ]]; then
    log_entry "$USAGE"
    exit 5
fi

# Validate wait duration
if [[ -z "$wait_duration" || "$wait_duration" -lt 0 || "$wait_duration" -gt "$MAX_SECS_WAIT" ]]; then
    log_entry "$USAGE"
    exit 6
fi

# Set environment and csproj file
env="${branch#code-}"
CSPROJ="$CUR_DIR/../../$env/$PROJ_NAME/$PROJ_NAME.csproj"
if [ ! -f "$CSPROJ" ]; then
    exit 7
fi

# Set git user info if different from current git config
USER_NAME="${USER_INFO["$branch"]%% *}"  # Extract user name
USER_EMAIL="${USER_INFO["$branch"]#* }"  # Extract user email
current_git_user=$(git config user.name)

if [[ "$current_git_user" != "$USER_NAME" ]]; then
    git config user.name "$USER_NAME" || {
        exit 8
    }
    git config user.email "$USER_EMAIL" || {
        exit 9
    }
fi

# Stash original, current branch
ORIGIN_STASHED=false
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [[ $(git status --porcelain) ]]; then
  git stash || {
    exit 10
  }
  ORIGIN_STASHED=true
fi

# Checkout target branch
git checkout "$branch" || {
    exit 11
}

# Stash target branch
TARGET_STASHED=false
if [[ $(git status --porcelain) ]]; then
  git stash || {
    exit 12
  }
  TARGET_STASHED=true
fi

# Set workflow driver file
DRIVER="$CUR_DIR/../../$env/$PROJ_NAME/workflow.driver"
[ ! -f "$DRIVER" ] && touch "$DRIVER"

# Git add, commit and push in a loop.
for i in $(seq 1 "$MAX_PUSHES"); do
  # Set commit message
  commit_msg="Auto-push $i of $MAX_PUSHES to $branch by $USER_NAME."

  # Set workflow.driver file
  echo "
  Push iteration: $i of $MAX_PUSHES
  Commit Message: $commit_msg
  Wait interval: $MAX_SECS_WAIT
  Target branch: $branch
  Environment: $env
  Driver: $DRIVER
  Csproj: $CSPROJ
  Username: $USER_NAME
  Email: $USER_EMAIL
  " > "$DRIVER"

  # git add
  git add -A || {
    exit 13
  }

  # git commit
  git commit -m "$commit_msg" || {
    log_entry "Commit error for $branch commit $i of $MAX_PUSHES"
    exit 14
  }

  # git push
  git push || {
    log_entry "Push error for $branch push $i of $MAX_PUSHES"
    exit 15
  }

  # Display driver file
  cat "$DRIVER" && echo

  # Wait if required
  if [ "$i" -lt "$num_pushes" ]; then
    log_entry "Waiting for $wait_duration seconds..."
    sleep "$wait_duration"
  fi
done

# Pop target branch
if $TARGET_STASHED && ! git stash pop; then
  log_entry "Stash pop error for $branch."
  exit 16
fi

# Switch to the original user and branch
git config user.name "$DEVOPS_USER" || {
    exit 8
}
git config user.email "$DEVOPS_EMAIL" || {
    exit 9
}
git checkout "$CURRENT_BRANCH" || {
    exit 17
}

# Pop the original branch
if $ORIGIN_STASHED && ! git stash pop; then
  log_entry "Stash pop error for $CURRENT_BRANCH."
  exit 18
fi

# Exit successfully
exit 0

# End of file
