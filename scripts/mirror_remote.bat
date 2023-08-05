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

REM Refresh the remote branches and create local branches
set "branchesFile=%TEMP%\branches.txt"
git fetch --all
git for-each-ref --format="%(refname:short)" refs/remotes/origin | findstr /v "HEAD" > "%branchesFile%"
for /f "tokens=*" %%i in ("%branchesFile%") do (
    git branch --track %%~ni %%i
    git pull 
)
del "%branchesFile%"

REM Switch to main and report
git checkout main
git pull
git branch

REM Return to the original directory
popd

endlocal

exit /b 0
