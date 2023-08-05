@echo off
setlocal EnableDelayedExpansion

REM Define a variable for the valid environment options
set "valid_environments=main development staging production"

REM Move to parent directory
if "%~dp0"=="%~dp0scripts\" (
    pushd "%~dp0"
)

REM Check if an argument is provided
if "%~1"=="" (
    echo Usage: %~nx0 ^<environment^>
    echo Available environments: %valid_environments%
    exit /b 1
)

REM Check if the argument is one of the valid environments
set "valid=0"
for %%e in (%valid_environments%) do (
    if /i "%~1"=="%%e" (
        set "valid=1"
    )
)

if !valid! equ 0 (
    echo Invalid environment. Please use one of the following options: %valid_environments%
    exit /b 1
)

REM Move to repository directory
pushd "%~dp0.."

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
    ) else (
        REM Branch exists, just check it out
        git checkout code-%~1
    )
)

REM Remove any existing sparse-checkout file
if exist .git\info\sparse-checkout (
    del .git\info\sparse-checkout
)

REM Ensure argument branch is fully committed and pushed
if /i "%~1"=="main" (
    set "argument_branch=main"
) else (
    set "argument_branch=code-%~1"
)
git rev-parse --verify %argument_branch% > nul
if errorlevel 1 (
    echo The branch %argument_branch% does not exist or is not fully committed and pushed.
    exit /b 1
)

REM If the argument is not "main," proceed with sparse checkout setup
if /i "%~1" neq "main" (

    REM Disable sparse-checkout if enabled
    git sparse-checkout disable

    REM Set sparse-checkout configuration with desired directories
    git sparse-checkout set --skip-checks %~1/ docs/ scripts/ tests/ LICENCE README.md howto

    REM Reapply the sparse-checkout specifications
    git sparse-checkout reapply

) else (
    REM Remove sparse checkout from main
    git sparse-checkout disable
)

REM Reset the branch
git reset --hard HEAD

REM Return to the original directory
popd

endlocal

exit /b 0
