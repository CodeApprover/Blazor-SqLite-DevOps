#!/bin/bash

# ===============================================
# Exit Codes
# ===============================================

# Script exits
SUCCESS=0
USER_ABORT=61
USAGE_ERR=62
INV_BRANCH=63
ITER_ERR=64
WAIT_ERR=65
CSPROJ_ERR=66

# Git exits
GIT_CONFIG_ERR=111
STASH_ORIG_ERR=112
TARGET_CHECKOUT_ERR=113
STASH_TARG_ERR=114
ADD_ERR=115
COMMIT_ERR=116
PUSH_ERR=117
TARGET_POP_ERR=118
ORIGIN_CHECKOUT_ERR=119
ORIGIN_POP_ERR=120

# ===============================================
# Configuration & Constants
# ===============================================

# Read configuration file
mapfile -t CONFIG_VALUES < <(grep -vE '^#|^[[:space:]]*$' .config)

# Set constants from config
DEVOPS_USER="${CONFIG_VALUES[0]}"
DEVOPS_EMAIL="${CONFIG_VALUES[1]}"
PROJ_NAME="${CONFIG_VALUES[2]}"
EXPECTED_DIR="${CONFIG_VALUES[3]}"
BRANCHES=("${CONFIG_VALUES[4]}" "${CONFIG_VALUES[5]}" "${CONFIG_VALUES[6]}" "${CONFIG_VALUES[7]}")
MAX_SECS_WAIT="${CONFIG_VALUES[8]}"
MAX_PUSHES="${CONFIG_VALUES[9]}"
CUR_DIR=$(pwd)

# Set user info from config
declare -A USER_INFO
USER_INFO=(
  ["${BRANCHES[0]}"]="$DEVOPS_USER $DEVOPS_EMAIL"
  ["${BRANCHES[1]}"]="${CONFIG_VALUES[10]} ${CONFIG_VALUES[11]}"
  ["${BRANCHES[2]}"]="${CONFIG_VALUES[12]} ${CONFIG_VALUES[13]}"
  ["${BRANCHES[3]}"]="${CONFIG_VALUES[14]} ${CONFIG_VALUES[15]}"
)

# ===============================================
# Warning & Usage
# ===============================================

# Set warning message
WARNING_=$(cat << EOM

WARNING: You are about to execute $0

This script makes commits and pushes them to a specified branch.
The first argument must be a valid branch name.

PARAMETERS: <branch-name> <number-of-pushes> <wait-seconds>

First parameter (mandatory string) one 'branch-name' options are:

    ${BRANCHES[1]}
    ${BRANCHES[2]}
    ${BRANCHES[3]}

Second parameter (optional int) sets the number of pushes.
If unset default is 1.

Third parameter (optional int) sets the interval in seconds between pushes.
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
)
WARNING=$WARNING_

# Set usage message
USAGE_=$(cat << EOM
Usage:   $0 branch-name (string) + pushes ( optional int) + wait_seconds ( optional int)
Example: $0 ${BRANCHES[1]} 3 600

Branch-name: ${BRANCHES[*]}
Pushes: 1 to $MAX_PUSHES (default 1)
Wait Seconds: 0 to $MAX_SECS_WAIT (default 0)

Branch Options:
${BRANCHES[*]}

EOM
)
USAGE=$USAGE_


# ===============================================
# Functions
# ===============================================

log_entry() {
    local message="$1"
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $message"
}

# ===============================================
# Validation
# ===============================================

# Check script is running from correct directory
EXPECTED_DIR="scripts/.devops"
if [[ "$CUR_DIR" != *"$EXPECTED_DIR" ]]; then
    log_entry "Error: Please run this script from within its own directory ($EXPECTED_DIR/)."
    exit "$USAGE_ERR"
fi

# Issue warning and parse user response
echo && echo "$WARNING"
echo && read -r -p "CONTINUE ??? [yes/no] " response
responses=("y" "Y" "yes" "YES" "Yes")
[[ ! "${responses[*]}" =~ $response ]] && log_entry "Aborted." && exit "$USER_ABORT"
echo

# Ensure correct number of arguments of the right type
[[ $# -lt 1 || $# -gt 3 || ! "$num_pushes" =~ ^[0-9]+$ || ! "$wait_duration" =~ ^[0-9]+$ ]] && log_entry "Invalid params." && echo "$USAGE" && exit "$USAGE_ERR"

# Set local variables
branch="$1"
num_pushes="${2:-1}"     # default 1
wait_duration="${3:-0}"  # default 0

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
    exit "$INV_BRANCH"
fi

# Validate iteration count
[[ "$num_pushes" -lt 1 || "$num_pushes" -gt "$MAX_PUSHES" ]] && log_entry "Invalid iteration count." && echo "$USAGE" && exit "$ITER_ERR"

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

# ===============================================
# Git Operations
# ===============================================

# Set branch user if different from devops user
if [[ "$USER_NAME" != "$DEVOPS_USER" ]]; then
    git config user.name "$USER_NAME" || { log_entry "Git config user.name failed."; exit "$GIT_CONFIG_ERR"; }
    git config user.email "$USER_EMAIL" || { log_entry "Git config user.email failed."; exit "$GIT_CONFIG_ERR"; }
fi

# Stash original, current branch
ORIGIN_STASHED=false
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [[ $(git status --porcelain) ]]; then
    git stash || { log_entry "Stash error for $CURRENT_BRANCH."; exit "$STASH_ORIG_ERR"; }
    ORIGIN_STASHED=true
fi

# Checkout target branch
git checkout "$branch" || { log_entry "Checkout error for $branch."; exit "$TARGET_CHECKOUT_ERR"; }

# Stash target branch
TARGET_STASHED=false
if [[ $(git status --porcelain) ]]; then
    git stash || { log_entry "Stash error for $branch."; exit "$STASH_TARG_ERR"; }
    TARGET_STASHED=true
fi

# Set workflow driver file
DRIVER="$CUR_DIR/../../$env/$PROJ_NAME/workflow.driver"
[ ! -f "$DRIVER" ] && touch "$DRIVER"

# Add, commit and push in a loop
for i in $(seq 1 "$num_pushes"); do
    commit_msg="Auto-push $i of $num_pushes to $branch by $USER_NAME."
    echo "
    Push iteration: $i of $num_pushes
    Commit Message: $commit_msg
    Wait interval: $wait_duration
    Target branch: $branch
    Environment: $env
    Driver: $DRIVER
    Csproj: $CSPROJ
    Username: $USER_NAME
    Email: $USER_EMAIL
    " > "$DRIVER"

    # git add
    git add "$DRIVER" || { log_entry "Add error."; exit "$ADD_ERR"; }

    # git commit
    git commit -m "$commit_msg" || { log_entry "Commit error for $branch push $i of $num_pushes."; exit "$COMMIT_ERR"; }

    # git push
    git push || { log_entry "Push error."; exit "$PUSH_ERR"; }

    # Display driver file
    cat "$DRIVER" && echo

    # Wait if required
    if [ "$i" -lt "$num_pushes" ]; then
        log_entry "Waiting for $wait_duration seconds..."
        for ((j = wait_duration; j > 0; j--)); do
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
    exit "$TARGET_POP_ERR"
fi

# Switch to the original user and branch
git config user.name "$DEVOPS_USER" || { log_entry "Git config user.name failed."; exit "$GIT_CONFIG_ERR"; }
git config user.email "$DEVOPS_EMAIL" || { log_entry "Git config user.email failed."; exit "$GIT_CONFIG_ERR"; }
git checkout "$CURRENT_BRANCH" || { log_entry "Checkout error for $CURRENT_BRANCH."; exit "$ORIGIN_CHECKOUT_ERR"; }

# Pop the original branch
if $ORIGIN_STASHED && ! git stash pop; then
    log_entry "Stash pop error for $CURRENT_BRANCH."
    exit "$ORIGIN_POP_ERR"
fi

# Exit successfully
log_entry "Completed."
exit "$SUCCESS"
