#!/bin/bash

set -e  # Exit on error
#set -x # Display commands

# Exits
SUCCESS=0
USER_ABORT=21
USAGE_ERR=22
INV_BRANCH=23
ITER_ERR=24
WAIT_ERR=25
CSPROJ_ERR=26

# Constants
DEV_USER="CodeApprover"
DEV_EMAIL="pucfada@pm.me"
PROJ_NAME="Blazor-SqLite-Golf-Club"
CUR_DIR=$(realpath "$(pwd)")
BRANCHES=("main" "code-development" "code-staging" "code-production")
MAX_WAIT=86400  # 24 hours
MAX_PUSHES=5

# Set usage message
USAGE="Usage: $0 <branch> [<num_pushes> <wait_duration>] # Branches: ${BRANCHES[*]}"

# Warn user
cat <<EOM

WARNING:

- You are about to execute $0

This script makes commits and pushes to the specified branch # no defaults.
for a an optional number of iterations # defaults to one.
waiting for optional duration seconds between pushes # defaults to zero.

USERS:

- Main: $DEV_USER (Email: $DEV_EMAIL)
- Development: ${USER_INFO["${code-}development"]}
- Staging: ${USER_INFO["${code-}staging"]}
- Production: ${USER_INFO["${code-}production"]}

CAUTION:

The script stashes and pops any stashes (if created)
to restore any changes in the current branch.
Consider making a backup before running this script.

$USAGE

EOM

# Parse user response
read -r -p "Continue? [yes/no] " response
responses=("y" "Y" "yes" "YES" "Yes")
[[ ! "${responses[*]}" =~ $response ]] && echo "Aborted." && exit "$USER_ABORT"

# Set local variables
branch="$1"
num_pushes="${2:-1}"     # default 1
wait_duration="${3:-0}"  # default 0

# Validate variables
[[ $# -lt 1 || $# -gt 3 || ! "$branch" =~ ^[a-zA-Z]+$ || ! "$num_pushes" =~ ^[0-9]+$ || ! "$wait_duration" =~ ^[0-9]+$ ]] && echo "$USAGE" && echo "Invalid params." && exit "$USAGE_ERR"
[[ ! " ${BRANCHES[*]} " =~ $branch ]] && echo "$USAGE" && echo "Invalid branch." && exit "$INV_BRANCH"
[[ "$num_pushes" -lt 1 || "$num_pushes" -gt "$MAX_PUSHES" ]] && echo "$USAGE" && echo "Invalid iteration count." && exit "$ITER_ERR"
[[ "$wait_duration" -lt 0 || "$wait_duration" -gt "$MAX_WAIT" ]] && echo "$USAGE" && echo "Invalid wait duration." && exit "$WAIT_ERR"

# Set user
declare -A USER_INFO
USER_INFO=(
  ["${BRANCHES[0]}"]="$DEV_USER $DEV_EMAIL"
  ["${BRANCHES[1]}"]="Code-Backups 404bot@pm.me"
  ["${BRANCHES[2]}"]="ScriptShifters lodgings@pm.me"
  ["${BRANCHES[3]}"]="$DEV_USER $DEV_EMAIL"
)
USER=${USER_INFO["$branch"]}
USER_NAME=${USER%% *}
USER_EMAIL=${USER#* }

# Set environment and csproj file
env="${branch#code-}"
CSPROJ="$CUR_DIR/../../$env/$PROJ_NAME/$PROJ_NAME.csproj"
[ ! -f "$CSPROJ" ] && echo "No file at $CSPROJ." && exit "$CSPROJ_ERR"

# Set git login
git config user.name "$USER_NAME"
git config user.email "$USER_EMAIL"

# Stash original, current branch
ORIGIN_STASHED=false
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [[ $(git status --porcelain) ]]; then
  if ! git stash; then
    echo "Stash error for $CURRENT_BRANCH."
    exit "$STASH_ORIG_ERR"
  fi
  ORIGIN_STASHED=true
fi

# Checkout target branch
if ! git checkout "$branch"; then
  echo "Checkout error for $branch."
  exit "$TARGET_CHECKOUT_ERR"
fi

# Stash target branch
TARGET_STASHED=false
if [[ $(git status --porcelain) ]]; then
  if ! git stash; then
    echo "Stash error for $branch."
    exit "$STASH_TARG_ERR"
  fi
  TARGET_STASHED=true
fi

# Set workflow driver file
DRIVER="$CUR_DIR/../../$env/$PROJ_NAME/workflow.driver"
[ ! -f "$DRIVER" ] && touch "$DRIVER"

# Function to update workflow.driver
update_workflow_driver() {
  echo "
    Push iteration: $1 of $num_pushes
    Commit Message: $2
    Wait interval: $wait_duration
    Target branch: $branch
    Environment: $env
    Driver: $DRIVER
    Csproj: $CSPROJ
    Username: $USER_NAME
    Email: $USER_EMAIL" > "$DRIVER"
}

# Add, commit and push in a loop.
for i in $(seq 1 "$num_pushes"); do
  commit_msg="Automated push $i of $num_pushes to $branch ($env) by $USER_NAME."
  update_workflow_driver "$i" "$commit_msg"

  if ! git add "$DRIVER"; then
    echo "Add error."
    exit "$ADD_ERR"
  fi

  if ! git commit -m "$commit_msg"; then
    echo "Commit error for $branch push $i of $num_pushes."
    exit "$COMMIT_ERR"
  fi

  if ! git push; then
    echo "Push error."
    exit "$PUSH_ERR"
  fi

  # Wait if required
  [ "$i" -lt "$num_pushes" ] && sleep "$wait_duration"
done

# Pop target branch
if $TARGET_STASHED && ! git stash pop; then
  echo "Stash pop error for $branch."
  exit "$TARGET_POP_ERR"
fi

# Switch to original user and branch
git config user.name "$DEV_USER"
git config user.email "$DEV_EMAIL"
if ! git checkout "$CURRENT_BRANCH"; then
  echo "Checkout error for $CURRENT_BRANCH."
  exit "$ORIGIN_CHECKOUT_ERR"
fi

# Pop original branch
if $ORIGIN_STASHED && ! git stash pop; then
  echo "Stash pop error for $CURRENT_BRANCH."
  exit "$ORIGIN_POP_ERR"
fi

# Exit successfully
echo "Completed."
exit "$SUCCESS"
