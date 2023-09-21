#!/bin/bash

set -e   # Exit if a command fails.
#set -x  # Print commands for debugging.

# Ensure a directory is specified.
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <directory>"
    exit 1
fi

TARGET_DIR="$1"

# Determine operating system.
OS=$(uname)

# Set line ending conversion tool.
LINE_ENDING_TOOL="unix2dos"
if [[ "$OS" == "Linux" ]]; then
    LINE_ENDING_TOOL="dos2unix"
fi

# Process line ending conversion.
find "$TARGET_DIR" -type f -exec "$LINE_ENDING_TOOL" {} \;

# Remove trailing spaces from all lines.
find "$TARGET_DIR" -type f -exec sed -i 's/[[:space:]]*$//' {} \;

# Replace multiple consecutive empty lines with one.
find "$TARGET_DIR" -type f -exec sed -i '/^$/N;/^\n$/D' {} \;
