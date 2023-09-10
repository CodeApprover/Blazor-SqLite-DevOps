#!/bin/bash

set -e
set -x

# This script automates a specific number of pushes at an optional interval, to a specified branch.

# It read a configuration file (.config)
# to populate parameters such as branch names, user details, etc.
# and ensures a clean working directory by stashing changes and later restoring them.

# Exit codes
SUCCESS=0
USER_ABORT=21
USAGE_ERR=22
BRANCH_ERR=23
ITER_ERR=24
WAIT_ERR=25
CSPROJ_ERR=26

# Git exit codes
GIT_CONFIG=90
GIT_STASH_ORIG=100
GIT_TARGET_CHECKOUT=101
GIT_STASH_TARGET=102
GIT_ADD=103
GIT_COMMIT=104
GIT_PUSH=105
GIT_TARGET_POP=106
GIT_ORIGIN_CHECKOUT=107
GIT_ORIGIN_POP=108

# Set constants from .config
mapfile -t CONFIG_VALUES < <(grep -vE '^#|^[[:space:]]*$' .config)
DEVOPS_USER="${CONFIG_VALUES[0]}"
DEVOPS_EMAIL="${CONFIG_VALUES[1]}"
PROJ_NAME="${CONFIG_VALUES[2]}"
EXPECTED_DIR="${CONFIG_VALUES[3]}"
BRANCHES=("${CONFIG_VALUES[4]}" "${CONFIG_VALUES[5]}" "${CONFIG_VALUES[6]}" "${CONFIG_VALUES[7]}")
MAX_SECS_WAIT="${CONFIG_VALUES[8]}"
MAX_PUSHES="${CONFIG_VALUES[9]}"
CUR_DIR="$(dirname "$0")"

# Set user info from config
declare -A USER_INFO
USER_INFO=(
  ["${BRANCHES[0]}"]="${CONFIG_VALUES[10]} ${CONFIG_VALUES[11]}"
  ["${BRANCHES[1]}"]="${CONFIG_VALUES[12]} ${CONFIG_VALUES[13]}"
  ["${BRANCHES[2]}"]="${CONFIG_VALUES[14]} ${CONFIG_VALUES[15]}"
  ["${BRANCHES[3]}"]="${CONFIG_VALUES[16]} ${CONFIG_VALUES[17]}"
)

# Set warning message
WARNING=$(cat << EOM

WARNING: You are about to execute $0
This script makes commits and pushes them to a specified branch.

PARAMETERS: <branch-name> <number-of-pushes> <wait-seconds>

1. Mandatory First parameter (string) 'branch-name' must be one of:
   ${BRANCHES[1]}  ${BRANCHES[2]}  ${BRANCHES[3]}

2. Optional Second parameter (int) sets the number of pushes
   (default is 1, max is $MAX_PUSHES seconds).

3. Optional Third parameter (int) sets the interval in seconds between pushes
   (default is 0, max is $MAX_SECS_WAIT).

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

# Set usage message
USAGE=$(cat << EOM
Usage:   $0 branch-name (mandatory string) + pushes ( optional int) + wait_seconds ( optional int)
Example: $0 ${BRANCHES[1]} 3 600
Branch Options: ${BRANCHES[1]} ${BRANCHES[2]} ${BRANCHES[3]}
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
[[ ! "${responses[*]}" =~ $response ]] && log_entry "Aborted." && exit $USER_ABORT
echo

# Check script is running from correct directory
EXPECTED_DIR="scripts/.devops"
if [[ "$(pwd)" != *"$EXPECTED_DIR" ]]; then
  log_entry "Error: Please run this script from within its own directory ($EXPECTED_DIR/)."
  exit "$USAGE_ERR"
fi

# ===============================================
# Main Script Logic
# ===============================================

# Set local variables
branch="$1"
MAX_PUSHES="${2:-1}"     # default 1
wait_duration="${3:-0}"  # default 0

# Ensure correct number of arguments, of the right type
[[ $# -lt 1 || $# -gt 3 || ! "$MAX_PUSHES" =~ ^[0-9]+$ || ! "$wait_duration" =~ ^[0-9]+$ ]] && log_entry "Invalid params." && echo "$USAGE" && exit "$USAGE_ERR"

# Validate branch
valid_branch=false
for valid_branch_name in "${BRANCHES[@]}"; do
  if [ "$branch" == "$valid_branch_name" ]; then
    valid_branch=true
    break
  fi
done

if [ "$valid_branch" == "false" ]; then
  log_entry "Invalid branch: $branch"
  echo "$USAGE"
  exit $BRANCH_ERR
fi

# Validate iteration count
[[ "$MAX_PUSHES" -lt 1 || "$MAX_PUSHES" -gt "$MAX_PUSHES" ]] && log_entry "Invalid iteration count." && echo "$USAGE" && exit "$ITER_ERR"

# Validate wait duration
[[ "$wait_duration" -lt 0 || "$wait_duration" -gt "$MAX_SECS_WAIT" ]] && log_entry "Invalid wait duration." && echo "$USAGE" && exit "$WAIT_ERR"

# Set user info
USER=${USER_INFO["$branch"]}
USER_NAME=${USER%% *}
USER_EMAIL=${USER#* }

# Set environment and csproj file
env="${branch#code-}"
CSPROJ="$CUR_DIR/../../$env/$PROJ_NAME/$PROJ_NAME.csproj"
if [ ! -f "$CSPROJ" ]; then
  log_entry "No file at $CSPROJ."
  exit "$CSPROJ_ERR"
fi

# Set git user info if different from current git config
if [[ "$USER_NAME" != "$DEVOPS_USER" ]]; then
  git config user.name "$USER_NAME" || { log_entry "Git config user.name failed."; exit $GIT_CONFIG; }
  git config user.email "$USER_EMAIL" || { log_entry "Git config user.email failed."; exit $GIT_CONFIG; }
fi

# Stash original, current branch
ORIGIN_STASHED=false
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [[ $(git status --porcelain) ]]; then
  git stash || { log_entry "Stash error for $CURRENT_BRANCH."; exit $GIT_STASH_ORIG; }
  ORIGIN_STASHED=true
fi

# Checkout target branch
git checkout "$branch" || { log_entry "Checkout error for $branch."; exit $GIT_TARGET_CHECKOUT; }

# Stash target branch
TARGET_STASHED=false
if [[ $(git status --porcelain) ]]; then
  git stash || { log_entry "Stash error for $branch."; exit $GIT_STASH_TARGET; }
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

  # git Git ag
  git add "$DRIVER" || { log_entry "Git add error."; exit $GIT_ADD; }

  # git commit
  git commit -m "$commit_msg" || { log_entry "Commit error for $branch push $i of $MAX_PUSHES."; exit $GIT_COMMIT; }

  # git push
  git push || { log_entry "Push error."; exit $GIT_PUSH; }

  # Display driver file
  cat "$DRIVER" && echo

  # Wait if required
  if [ "$i" -lt "$MAX_PUSHES" ]; then
    log_entry "Waiting for $MAX_SECS_WAIT seconds..."
    for ((j = MAX_SECS_WAIT; j > 0; j--)); do
      days=$((j / 86400))
      hours=$(( (j % 86400) / 3600 ))
      minutes=$(( (j % 3600) / 60 ))
      seconds=$((j % 60))
      printf "Time remaining: %02d:%02d:%02d:%02d\r" "$days" "$hours" "$minutes" "$seconds"
      sleep 1
    done
    log_entry "Time remaining: 00:00:00:00"
  fi
done

# Pop target branch
if $TARGET_STASHED && ! git stash pop; then
  log_entry "Stash pop error for $branch."
  exit $GIT_TARGET_POP
fi

# Switch to the original user and branch
git config user.name "$DEVOPS_USER" || { log_entry "Git config user.name failed."; exit $GIT_CONFIG; }
git config user.email "$DEVOPS_EMAIL" || { log_entry "Git config user.email failed."; exit $GIT_CONFIG; }
git checkout "$CURRENT_BRANCH" || { log_entry "Checkout error for $CURRENT_BRANCH."; exit $GIT_ORIGIN_CHECKOUT; }

# Pop the original branch
if $ORIGIN_STASHED && ! git stash pop; then
  log_entry "Stash pop error for $CURRENT_BRANCH."
  exit $GIT_ORIGIN_POP
fi

# Exit successfully
log_entry "$0 completed successfully."
exit $SUCCESS
