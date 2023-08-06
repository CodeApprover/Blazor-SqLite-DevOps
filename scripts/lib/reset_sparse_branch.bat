@echo off
setlocal EnableDelayedExpansion

REM Set valid branches
set "valid_branchs=main code-development code-staging code-production"

REM Check if argument is provided
if "%~1"=="" (
    echo Usage: %~nx0 ^<branch^>
    echo Available branches: %valid_branchs%
    exit /b 1
)

REM Check if argument is valid branch
set "valid=0"
for %%e in (%valid_branchs%) do (
    if /i "%~1"=="%%e" (
        set "valid=1"
    )
)
if !valid! equ 0 (
    echo Invalid branch. Please use one of the following options: %valid_branchs%
    exit /b 1
)

REM Move to repository directory
pushd "%~dp0.."

REM Perform Git operations
git sparse-checkout disable
git reset --hard "origin/%~1"
git checkout "%~1"
git pull

REM List contents of main app directory
echo Contents of the main app directory:
dir /b /a-d

REM Return to the original directory
popd

endlocal
exit /b 0
