@echo off
setlocal EnableDelayedExpansion

REM Set valid environments
set "valid_environments=main development staging production"

REM Check if argument is provided
if "%~1"=="" (
    echo Usage: %~nx0 ^<environment^>
    echo Available environments: %valid_environments%
    exit /b 1
)

REM Check if argument is valid environments
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

git sparse-checkout disable
git reset --hard HEAD
git fetch
git pull

REM Return to the original directory
popd

endlocal