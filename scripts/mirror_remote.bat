@echo off
setlocal EnableDelayedExpansion

REM Array of branches to ignore
set "branches=main code-development code-staging code-production"

REM Move to repository directory
pushd "%~dp0.."
REM Switch to main, reset to remote
git checkout main
git sparse-checkout disable
git reset --hard HEAD

REM Fetch all branches from the remote repository
git fetch --all

REM Get parent directory of TEMP
for %%i in ("%TEMP%") do set "parentDir=%%~dpi.."
set "branchesFile=%parentDir%\branches.txt"

REM Refresh the remote branches and create local branches
git fetch --all
git for-each-ref --format="%%(refname:short)" refs/remotes/origin | findstr /v "HEAD" | findstr /v "origin/origin" > "%branchesFile%"
for /f "tokens=*" %%i in (%branchesFile%) do (
    REM Strip 'origin/' from the remote branch name
    set "localBranch=%%i"
    set "localBranch=!localBranch:origin/=!"
    set "createBranch=1"
    
    REM Check if the local branch is in the branches array
    for %%b in (%branches%) do (
        if "%%b"=="!localBranch!" (
            set "createBranch=0"
        )
    )
    
    if "!createBranch!"=="1" (
        REM Check if local branch already exists
        git rev-parse --verify --quiet "!localBranch!" >nul 2>&1
        if errorlevel 1 (
            REM Create and checkout a new local branch that tracks the remote branch
            git checkout -b "!localBranch!" "%%i"
            REM Push the local branch to the remote repository
            git push -u origin "!localBranch!"
        )
    )
)

REM Delete specific local branches defined in "branches" except main
for %%b in (%branches%) do (
    if "%%b" neq "main" (
        git branch -D %%b > nul 2>&1
    )
)

REM Switch to main and report
git checkout main
git fetch --all
git pull
git push
git branch

REM Return to the original directory
popd

endlocal
exit /b 0
