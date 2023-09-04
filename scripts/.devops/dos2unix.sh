#!/bin/bash

set -e  # Exit if a command fails.
set -x  # Print commands for debugging.

# Replace dos line endings with unix.
find . -name "*.sh" -exec dos2unix {} \;

# Remove trailing whitespace from lines.
find . -name "*.sh" -exec sed -i 's/[ \t]*$//' {} \;

# Modify empty lines as per requirements.
find . -name "*.sh" -exec sed -i '/^run: |/{n;s/^[[:space:]]*$/ /}; /^[[:space:]]*$/d' {} \;
