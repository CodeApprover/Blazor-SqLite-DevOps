@echo off
setlocal EnableDelayedExpansion

REM Array of branches to process
set "branches=main code-development code-staging code-production"

REM Move to repository directory
pushd "%~dp0.."
REM Switch to main, reset to remote
git checkout main
git reset --hard "origin/main"

REM Fetch all branches from the remote repository
git fetch --all

REM Process the specific branches
for %%b in (%branches%) do (
    REM Check if remote branch exists
    git ls-remote --exit-code --heads origin %%b >nul 2>&1
    if errorlevel 1 (
        REM If remote branch does not exist, delete local forcefully
        git branch -D %%b >nul 2>&1
    ) else (
        REM Check if local branch already exists
        git rev-parse --verify --quiet "%%b" >nul 2>&1
        if errorlevel 1 (
            REM If not, create and checkout a new local branch that tracks the remote branch
            git checkout -b "%%b" "origin/%%b"
        ) else (
            REM If exists, check out and reset to match remote
            git checkout "%%b"
            git reset --hard "origin/%%b"
        )
    )
)

REM Switch to main
git checkout main

REM Report
git branch -a

REM Return to the original directory
popd

endlocal
exit /b 0
