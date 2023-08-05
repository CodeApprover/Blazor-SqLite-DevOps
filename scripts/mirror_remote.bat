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

REM Delete specific local branches defined in "branches"
for %%b in (%branches%) do (
    if "%%b" neq "main" (
        echo Deleting branch %%b
        git branch -D %%b > nul 2>&1
    )
)

REM Create and reset new branches that mirror the remote
for %%b in (%branches%) do (
    git ls-remote --exit-code origin refs/heads/%%b >nul 2>&1
    if !ERRORLEVEL! equ 0 (
        git checkout -b %%b
        git reset --hard origin/%%b
        git push --set-upstream origin %%b
    ) else (
        echo Remote branch %%b does not exist, skipping
    )
)

REM Refresh the remote branches and create local tracking branches
git fetch --all
git for-each-ref --format="%(refname:short)" refs/remotes/origin | findstr /v "HEAD" > branches.txt
for /f "tokens=*" %%i in (branches.txt) do (
    git branch --track %%~ni %%i
)
del branches.txt

REM Switch to main and report
git checkout main
git branch

REM Return to the original directory
popd

endlocal
