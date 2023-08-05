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
        git branch -D %%b > nul 2>&1
    )
)

REM Get parent directory of TEMP
for %%i in ("%TEMP%") do set "parentDir=%%~dpi.."
set "branchesFile=%parentDir%\branches.txt"

REM Refresh the remote branches and create local branches
git fetch --all
git for-each-ref --format="%(refname:short)" refs/remotes/origin | findstr /v "HEAD" | findstr /v "origin/origin" > "%branchesFile%"
for /f "tokens=*" %%i in (%branchesFile%) do (
    if "%%i" neq "%branchesFile%" (
        REM Strip 'origin/' from the remote branch name
        set "localBranch=%%~ni"
        set "localBranch=!localBranch:origin/=!"
        REM Check if the local branch is in the branches array and main branch
        if "!localBranch!" neq "origin" if "!localBranch!" neq "main" (
            REM Create and checkout a new local branch that tracks the remote branch
            git checkout -b "!localBranch!" "%%i"
            REM Push the local branch to the remote repository
            git push -u origin "!localBranch!"
        )
    )
)

REM Switch to main and report
git checkout main
git fetch --all
git pull
git push -u
git branch

REM Return to the original directory
popd

endlocal
exit /b 0
