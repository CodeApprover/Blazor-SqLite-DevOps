#!/bin/bash

set -e
set -x
find . -name "*.sh" -exec dos2unix {} \; -exec sed -i 's/^[ \t]*$//' {} \;
