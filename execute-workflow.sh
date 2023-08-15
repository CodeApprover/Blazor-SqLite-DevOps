#!/bin/bash

# Disable command echo
set +x

# Commit and push to test workflows [skip ci]
echo "0" >> workflow.driver
git add workflow.driver
git commit -m "running dev push to test workflows #0 [skip ci]"
git push

# Refresh local branch
git pull
ls -la
sleep 30

# Commit and push to test workflows
echo "0" >> workflow.driver
git add workflow.driver
git commit -m "running dev push to test workflows #0"
git push

# Enable command echo
set -x
