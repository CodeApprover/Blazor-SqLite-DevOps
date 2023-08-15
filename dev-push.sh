#!/bin/bash

# Disable command echo
set +x

# First commit and push to test workflows [skip ci]
echo "# use to commit a change, drive workflow execution" > workflow.driver
git add workflow.driver
git commit -m "running dev push to test workflows #0 [skip ci]"
git push

# Second commit and push to test workflows [skip ci]
echo "# use to drive workflow" > workflow.driver
git add workflow.driver
git commit -m "running dev push to test workflows #0 [skip ci]"
git push

# Third commit and push to test workflows [skip ci]
echo "# use to commit a change, drive workflow execution" > workflow.driver
git add workflow.driver
git commit -m "running dev push to test workflows #0"
git push

# Enable command echo
set -x
