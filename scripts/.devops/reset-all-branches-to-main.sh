#!/bin/bash

# Script Description: Resets local main to remote main and updates the specific branches.
# Reads a configuration file (.config) for branch names, user details, and more.

# Exit codes
SUCCESS=0
USER_ABORT=60
USAGE_ERR=61
CP_ERR=62
RM_ERR=63
NAV_ERR=64
MKDIR_ERR=65
CD_ERR=66
BRANCH_ERR=67

# Git exit codes
GIT_CONFIG_ERR=120
GIT_MAIN_ERR=121
GIT_CREATE_ERR=122
GIT_DELETE_ERR=123
GIT_CHECKOUT_ERR=124
GIT_STASH_ERR=125
GIT_PUSH_ERR=126
GIT_ADD_ERR=127
GIT_COMMIT_ERR=128

# Load constants from .config
mapfile -t CONFIG_VALUES < <(grep -vE '^#|^[[:space:]]*$' .config)
DEVOPS_USER="${CONFIG_VALUES[0]}"
DEVOPS_EMAIL="${CONFIG_VALUES[1]}"
EXPECTED_DIR="${CONFIG_VALUES[3]}"
BRANCHES=("${CONFIG_VALUES[4]}" "${CONFIG_VALUES[5]}" "${CONFIG_VALUES[6]}" "${CONFIG_VALUES[7]}")
CUR_DIR=$(pwd)

# Display Warning
cat << EOM
WARNING:
Executing $0 will replace the local ${BRANCHES[3]} with remote ${BRANCHES[3]}.
It will reset the ${BRANCHES[0]}, ${BRANCHES[1]}, and ${BRANCHES[2]} branches both locally and remotely.
Parameters are read from: $CUR_DIR/.config
CAUTION: This can lead to loss of unsaved work. Consider backups before executing.
USAGE: $0
EOM

# Logging function
log_entry() {
    local message="$1"
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $message"
}

# Issue warning and parse user response
echo && echo "$WARNING"
echo && read -r -p "CONTINUE ??? [yes/no] " response
responses=("y" "Y" "yes" "YES" "Yes")
[[ ! "${responses[*]}" =~ $response ]] && log_entry "Aborted." && exit "$USER_ABORT"
echo

# Ensure we're in the correct directory
[[ "$(pwd)" != *"$EXPECTED_DIR" ]] && log_entry "Please run from $EXPECTED_DIR." && exit "$USAGE_ERR"

# Move to root directory
cd ../.. || { log_entry "Navigation error."; exit "$NAV_ERR"; }

# Set Git User
git config user.name "$DEVOPS_USER" || { log_entry "Git config user.name error."; exit "$GIT_CONFIG_ERR"; }
git config user.email "$DEVOPS_EMAIL" || { log_entry "Git config user.email error."; exit "$GIT_CONFIG_ERR"; }

# Ensure we're on the main branch
git checkout "${BRANCHES[3]}" || { log_entry "Checkout main error."; exit "$GIT_CHECKOUT_ERR"; }
git stash || { log_entry "Stash error on main."; exit "$GIT_STASH_ERR"; }

# Reset main branch to mirror remote
git fetch origin || { log_entry "Git fetch error."; exit "$GIT_MAIN_ERR"; }
git reset --hard origin/main || { log_entry "Git reset error."; exit "$GIT_MAIN_ERR"; }

# Recreate each code- branch
for branch in "${BRANCHES[@]:0:3}"; do

    # Checkout, stash and delete local branch
    if git show-ref --verify --quiet "refs/heads/$branch"; then
        git checkout "$branch" || { log_entry "Checkout $branch error."; exit "$GIT_CHECKOUT_ERR"; }
        git stash || { log_entry "Stash error on $branch."; exit "$GIT_STASH_ERR"; }
        git checkout "${BRANCHES[3]}" || { log_entry "Checkout main error."; exit "$GIT_CHECKOUT_ERR"; }
        git branch -D "$branch" || { log_entry "Deleting branch $branch error."; exit "$BRANCH_ERR"; }
    fi

    # Delete remote branch if it exists
    git ls-remote --heads origin "$branch" | grep -sw "$branch" >/dev/null && git push origin --delete "$branch" || { log_entry "Deleting remote branch $branch error."; exit "$GIT_DELETE_ERR"; }

    # Create a new branch from main
    git checkout -b "$branch" || { log_entry "Error creating branch $branch."; exit "$GIT_CREATE_ERR"; }

    # Debug info
    log_entry "Current branch: $(git branch --show-current)"
    log_entry "Current directory: $(pwd)"

    # Confirm the directory exists and has content before copying
    env_name="${branch#code-}"
    if [[ -d "scripts/$env_name/" && $(ls -A "scripts/$env_name/") ]]; then
        cp -r "scripts/$env_name/"* toolbox/ || { log_entry "Error copying scripts to toolbox."; exit "$CP_ERR"; }
    else
        log_entry "Directory scripts/$env_name/ does not exist or is empty."
        exit "$CD_ERR"
    fi

    # Cleanup directories based on branch
    case "$branch" in
        "${BRANCHES[0]}") rm -rf staging production > /dev/null 2>&1 || { log_entry "Error removing directories from ${BRANCHES[0]}."; exit "$RM_ERR"; } ;;
        "${BRANCHES[1]}") rm -rf production > /dev/null 2>&1 || { log_entry "Error removing directories from ${BRANCHES[1]}."; exit "$RM_ERR"; } ;;
        "${BRANCHES[2]}") rm -rf development > /dev/null 2>&1 || { log_entry "Error removing directories from ${BRANCHES[2]}."; exit "$RM_ERR"; } ;;
    esac

    # Remove scripts
    rm -rf scripts || { log_entry "Error removing scripts."; exit "$RM_ERR"; }

    # Add, commit, and push to remote
    git add . || { log_entry "Git add error."; exit "$GIT_ADD_ERR"; }
    git commit -m "Updated $branch from main" || { log_entry "Git commit error."; exit "$GIT_COMMIT_ERR"; }
    git push -u origin "$branch" || { log_entry "Git push error."; exit "$GIT_PUSH_ERR"; }

done

# Final steps
git checkout "${BRANCHES[3]}" || { log_entry "Checkout main error."; exit "$GIT_CHECKOUT_ERR"; }
git stash drop || { log_entry "Stash drop error."; exit "$GIT_STASH_ERR"; }
cd "$CUR_DIR" || { log_entry "Error navigating back to $CUR_DIR."; exit "$CD_ERR"; }

# Completion message
log_entry "$0 finished."
exit "$SUCCESS"
