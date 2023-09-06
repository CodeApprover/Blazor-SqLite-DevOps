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
STASH_ORIG_ERR=27
TARGET_CHECKOUT_ERR=28
STASH_TARG_ERR=29
ADD_ERR=30
COMMIT_ERR=31
PUSH_ERR=32
TARGET_POP_ERR=33
ORIGIN_CHECKOUT_ERR=34
ORIGIN_POP_ERR=35

# Constants
DEV_USER="CodeApprover"
DEV_EMAIL="pucfada@pm.me"
PROJ_NAME="Blazor-SqLite-Golf-Club"
CUR_DIR=$(realpath "$(pwd)")
BRANCHES=("main" "code-development" "code-staging" "code-production")
MAX_WAIT=86400  # 24 hours
MAX_PUSHES=5

# Set user
declare -A USER_INFO
USER_INFO=(
    ["${BRANCHES[0]}"]="$DEV_USER $DEV_EMAIL"
    ["${BRANCHES[1]}"]="Code-Backups 404bot@pm.me"
    ["${BRANCHES[2]}"]="ScriptShifters lodgings@pm.me"
    ["${BRANCHES[3]}"]="$DEV_USER $DEV_EMAIL"
)

# Set usage message
USAGE_ARR=$(cat <<EOM
  Usage:   $0  + branch-name (string) [ + pushes (int) + wait_seconds (int) ]
  Example: $0 ${BRANCHES[1]} 3 600

  Branch-name: ${BRANCHES[*]}
  Pushes: 1 to $MAX_PUSHES
  Wait Seconds: 0 to $MAX_WAIT

  Branch Options:
  ${BRANCHES[*]}

EOM
)
USAGE=$USAGE_ARR

# Warn user
cat <<EOM

WARNING: You are about to execute $0

  This script makes commits and pushes them to a specified branch.
  The first argument must be a valid branch name.

PARAMETERS:

  First parameter (mandatory) 'branch-name' [string] sets the target branch.
  Valid branches:
                    ${BRANCHES[0]}
                    ${BRANCHES[1]}
                    ${BRANCHES[2]}
                    ${BRANCHES[3]}

  Second parameter (optional) 'pushes' [int] sets the number of pushes.
  If unset default is 1.

  Third parameter (optional) 'wait seconds' [int] sets the interval between pushes.
  If unset default is 0.

GIT USERS: The script presumes the following git users are authorised:

                  ${USER_INFO[${BRANCHES[0]}]}
                  ${USER_INFO[${BRANCHES[1]}]}
                  ${USER_INFO[${BRANCHES[2]}]}
                  ${USER_INFO[${BRANCHES[3]}]}

CAUTION: Consider making a backup before execution.

  Note: This script stashes and pops any stashes (if created)
  to restore any changes in the current branch.

EOM

# Parse user response
read -r -p "CONTINUE ??? [yes/no] " response
responses=("y" "Y" "yes" "YES" "Yes")
[[ ! "${responses[*]}" =~ $response ]] && echo "Aborted." && exit "$USER_ABORT"
echo

# Set local variables
branch="$1"
num_pushes="${2:-1}"     # default 1
wait_duration="${3:-0}"  # default 0

# Validate branch name
valid_branch=false
for valid_branch_name in "${BRANCHES[@]}"; do
    if [ "$branch" == "$valid_branch_name" ]; then
        valid_branch=true
        break
    fi
done

if [ "$valid_branch" == "false" ]; then
    echo "$USAGE"
    echo "Invalid branch: $branch"
    exit "$INV_BRANCH"
fi

# Validate variables
[[ $# -lt 1 || $# -gt 3 || ! "$num_pushes" =~ ^[0-9]+$ || ! "$wait_duration" =~ ^[0-9]+$ ]] && echo "$USAGE" && echo "Invalid params." && exit "$USAGE_ERR"
[[ "$num_pushes" -lt 1 || "$num_pushes" -gt "$MAX_PUSHES" ]] && echo "$USAGE" && echo "Invalid iteration count." && exit "$ITER_ERR"
[[ "$wait_duration" -lt 0 || "$wait_duration" -gt "$MAX_WAIT" ]] && echo "$USAGE" && echo "Invalid wait duration." && exit "$WAIT_ERR"

# Set user info
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

# Add, commit, and push in a loop.
for i in $(seq 1 "$num_pushes"); do
    commit_msg="Automated push $i of $num_pushes to $branch $env environment by $USER_NAME."
    update_workflow_driver "$i" "$commit_msg"

    # git add
    if ! git add "$DRIVER"; then
        echo "Add error."
        exit "$ADD_ERR"
    fi

    # git commit
    if ! git commit -m "$commit_msg"; then
        echo "Commit error for $branch push $i of $num_pushes."
        exit "$COMMIT_ERR"
    fi

    # git push
    if ! git push; then
        echo "Push error."
        exit "$PUSH_ERR"
    fi

    # Display driver file
    cat "$DRIVER" && echo

    # Wait if required
    if [ "$i" -lt "$num_pushes" ]; then
        echo "Waiting for $wait_duration seconds..."
        for ((j = wait_duration; j > 0; j--)); do
            days=$((j / 86400))
            hours=$(( (j % 86400) / 3600 ))
            minutes=$(( (j % 3600) / 60 ))
            seconds=$((j % 60))
            printf "Time remaining: %02d:%02d:%02d:%02d\r" "$days" "$hours" "$minutes" "$seconds"
            sleep 1
        done
        echo "Time remaining: 00:00:00:00"
    fi
done

# Pop target branch
if $TARGET_STASHED && ! git stash pop; then
    echo "Stash pop error for $branch."
    exit "$TARGET_POP_ERR"
fi

# Switch to the original user and branch
git config user.name "$DEV_USER"
git config user.email "$DEV_EMAIL"
if ! git checkout "$CURRENT_BRANCH"; then
    echo "Checkout error for $CURRENT_BRANCH."
    exit "$ORIGIN_CHECKOUT_ERR"
fi

# Pop the original branch
if $ORIGIN_STASHED && ! git stash pop; then
    echo "Stash pop error for $CURRENT_BRANCH."
    exit "$ORIGIN_POP_ERR"
fi

# Exit successfully
echo "Completed."
exit "$SUCCESS"
