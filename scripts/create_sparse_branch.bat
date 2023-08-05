@echo off
setlocal EnableDelayedExpansion

REM Move to parent directory
if "%~dp0"=="%~dp0scripts\" (
    pushd "%~dp0"
)

REM Define valid branch names
set "valid_branch_names= development staging production"

REM Check if an argument is provided
if "%~1"=="" (
    echo Usage: %~nx0 ^<branch_name^>
    echo Available environments: %valid_branch_names%
    exit /b 1
)

REM Check if the argument is one of the valid environments
set "valid=0"
set "valid_branches="
for %%e in (%valid_branch_names%) do (
    if /i "%~1"=="%%e" (
        set "valid=1"
    )
    set "valid_branches=!valid_branches! code-%%e"
)

REM Prompt valid branches
if !valid! equ 0 (
    echo Invalid branch requested. Please use one of the following options: !valid_branches!
    exit /b 1
)


REM Move to repository directory
pushd "%~dp0.."

set "branch_created=0"
REM Check out the appropriate branch
if /i "%~1"=="main" (
    git checkout main
) else (
    REM Check if the branch exists on the remote
    git ls-remote --exit-code --heads origin code-%~1 >nul 2>&1
    if errorlevel 1 (
        REM Branch does not exist on the remote, create it locally
        git checkout -b code-%~1
        REM Push the new branch to the remote
        git push -u origin code-%~1
        set "branch_created=1"
    ) else (
        REM Branch exists on the remote, delete local branch if it exists
        git branch -D code-%~1 2>nul
        REM Check out the remote branch
        git checkout -b code-%~1 origin/code-%~1
        set "branch_created=1"
    )
)

if "!branch_created!"=="0" (
    echo Branch was not created, remaining on current branch.
)

REM Rest of the code goes here ...

REM Return to the original directory
popd

endlocal
exit /b 0
