#!/bin/bash

set -e   # Exit if a command fails.
#set -x  # Print commands for debugging.

# Determine operating system.
OS=$(uname)

# Normalise path separators based on operating system.
CURRENT_DIR=$(pwd)
if [[ "$OS" != "Linux" ]]; then # Windows/MinGW.
    CURRENT_DIR=${CURRENT_DIR//\\/\/}
fi

# Ensure script runs from scripts dir or subdir.
EXPECTED_DIR="scripts"
if [[ "$CURRENT_DIR" != *"$EXPECTED_DIR"* ]]; then
    echo "Error: Please run $0 from the '$EXPECTED_DIR' directory."
    exit 1
fi

# Set line ending conversion tool.
LINE_ENDING_TOOL="unix2dos"
if [[ "$OS" == "Linux" ]]; then
    LINE_ENDING_TOOL="dos2unix"
fi

# Process line ending conversion.
find "$CURRENT_DIR" -type f -exec "$LINE_ENDING_TOOL" {} \;

# Remove spaces from all empty lines and condense multiple blank lines.
find "$CURRENT_DIR" -type f -exec sed -i -e 's/^[[:space:]]*$//' -e '/^$/N;/^\n$/D' {} \;

# Ensure lines after `run: |` are empty with a single space.
find "$CURRENT_DIR" -type f -exec sed -i '/run: |/{n; s/^$/ /}' {} \;
