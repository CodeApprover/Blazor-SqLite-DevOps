@echo off
setlocal EnableDelayedExpansion

REM Array of branches to update
set "branches=code-development code-staging code-production"

REM Move to repository directory
pushd "%~dp0.."
REM Switch to main, reset to remote
git checkout main
git sparse-checkout disable
git reset --hard HEAD

REM Fetch all branches from the remote repository
git fetch --all

REM Delete all local branches except the "main" branch
for %%b in (%branches%) do (
    if "%%b" neq "main" (
        echo Deleting branch %%b
        git branch -D %%b > nul 2>&1
    )
)

REM Create and reset new branches
for %%b in (%branches%) do (
    git checkout -b %%b
    git reset --hard HEAD
)

REM Switch to main and report
git checkout main
git branch

REM Return to the original directory
popd

endlocal
