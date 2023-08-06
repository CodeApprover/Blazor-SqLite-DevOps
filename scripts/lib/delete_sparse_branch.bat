@echo off
setlocal EnableDelayedExpansion

REM Move to parent directory
if "%~dp0"=="%~dp0scripts\" (
    pushd "%~dp0"
)

REM Define a variable for the valid environment options
set "valid_branches=code-development code-staging code-production"

REM Check if an argument is provided
if "%~1"=="" (
    echo Usage: %~nx0 ^<branch_name^>
    echo Available branches: %valid_branches%
    exit /b 1
)

REM Check if the argument is one of the valid branches
set "valid=0"
for %%e in (%valid_branches%) do (
    if /i "%~1"=="%%e" (
        set "valid=1"
    )
)

REM Prompt valid branches
if !valid! equ 0 (
    echo Invalid branch requested. Please use one of the following options: %valid_branches%
    exit /b 1
)

REM Move to repository directory
pushd "%~dp0.."

REM Check if the branch exists locally
git branch --list | findstr /R /C:"^  *%~1$" >nul
if errorlevel 1 (
    echo Branch %~1 does not exist locally.
) else (
    REM Delete the branch locally
    git branch -D %~1
    echo Deleted local branch %~1.
)

REM Check if the branch exists on the remote
git ls-remote --exit-code --heads origin %~1 >nul 2>&1
if errorlevel 1 (
    echo Branch %~1 does not exist on the remote.
) else (
    REM Delete the branch remotely
    git push origin --delete %~1
    echo Deleted remote branch %~1.
)

REM Return to the original directory
popd

endlocal
exit /b 0
