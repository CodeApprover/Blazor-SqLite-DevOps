@echo off
setlocal EnableDelayedExpansion

REM ########################################################################
REM Setup
REM ########################################################################

REM Ensure the script is executed from the top directory of the repository.
if "%~dp0"=="%~dp0scripts\lib\" (
    pushd "..\.."
) else if "%~dp0"=="%~dp0scripts\" (
    pushd ".."
)

REM Set the main directory of the repository.
set "REPO_DIR=%CD%"

REM Define the valid branch names and capture the branch name provided as an argument.
set "valid_branches=code-development code-staging code-production"
set "branch=%~1"

REM Display a script description and check if the provided branch name is valid.
echo.
echo =======================================================================
echo  - Creates clean Git branch for %branch%:
echo  - %valid_branches%
echo.
echo - If a branch doesn't exist locally, it's created.
echo - Local changes will be lost.
echo - Untracked files are stashed and removed.
echo - Tracked files are replaced by remote counterparts.
echo.
echo  - WARNING: Use with caution.
echo =======================================================================
echo.

REM Fetch updates from all remote branches.
git fetch --all >nul

REM Check if a branch name was provided as an argument.
if "%branch%"=="" (
    echo.
    echo Usage: %~nx0 ^<branch_name^>
    echo Available branches:
    echo %valid_branches%
    echo.
    exit /b 1
)

REM Validate the provided branch name against the list of valid branches.
set "valid=0"
for %%e in (%valid_branches%) do (
    if /i "%branch%"=="%%e" (
        set "valid=1"
    )
)

REM If the provided branch name is invalid, display an error message.
if !valid! equ 0 (
    echo.
    echo Invalid branch requested.
    echo Please use one of the following options:
    echo %valid_branches%
    echo.
    exit /b 1
)

REM Define a temporary branch name and directory for operations.
set "temp_branch=Temp"
set "temp_dir=%TEMP%\temp_dir"

REM If temp_dir exists, delete it. Then, create a fresh temp_dir.
if exist "%tempDir%" rmdir /s /q "%tempDir%"
mkdir "%tempDir%"

REM If temp_branch exists locally, delete it. Then, create and checkout a new temp_branch.
git rev-parse --verify %temp_branch% >nul
if not errorlevel 1 git branch -D %temp_branch% >nul
git checkout -b %temp_branch% >nul

REM ########################################################################
REM Create Empty Requested Branch Locally
REM ########################################################################

REM Check if the requested branch exists locally.
git rev-parse --verify %branch% >nul

REM If the branch exists locally, checkout the branch, stash any changes and delete all files associated with it.
if not errorlevel 1 (

    git checkout %branch% >nul
    git stash push -u -m "Stash before deleting %branch%" >nul
    echo "Changes have been stashed with the message: Stash before deleting %branch%."
    echo "Please note this for future reference."
    timeout /t 5
    git rm -rf %REPO_DIR%/* >nul
    git branch -D %branch% >nul

) else (
    REM If the branch doesn't exist locally, create an empty orphan branch with that name.
    git checkout --orphan %branch% >nul
    git rm -rf . >nul
)

REM Switch back to the temporary branch for further operations.
git checkout %temp_branch% >nul

REM ########################################################################
REM Populate Requested Branch Locally
REM ########################################################################

REM Check if the requested branch exists on the remote.
git ls-remote --exit-code --heads origin %branch% >nul

REM If the branch doesn't exist remotely, clone the main branch from the remote repository into temp_dir.
if errorlevel 1 (
    for /f "tokens=*" %%i in ('git remote get-url origin') do set "remoteURL=%%i"
    git clone "%remoteURL%" -b main "%temp_dir%" >nul

) else ( 
    REM If the branch exists remotely, clone that specific branch into temp_dir.
    git clone "%remoteURL%" -b %branch% %temp_dir% >nul
)

REM After cloning, checkout the %branch% locally and copy the contents of temp_dir to the current directory (REPO_DIR).
git checkout %branch% >nul
xcopy /E /I /Y "%temp_dir%\*" "%REPO_DIR%"

REM Cleanup: Delete all files in temp_dir, the temp_dir itself, and the temp_branch.
git rm -rf %temp_dir%/* >nul
git clean %temp_dir% -fd >nul
rmdir /s /q "%temp_dir%" >nul
git branch -D %temp_branch% >nul

REM ########################################################################
REM Rename Directory Based on Branch
REM ########################################################################

REM Determine the desired directory name based on the branch.
if /i "%branch%"=="code-development" set "desired_dir_name=development"
if /i "%branch%"=="code-staging" set "desired_dir_name=staging"
if /i "%branch%"=="code-production" set "desired_dir_name=production"

REM Rename directories as needed based on the branch name.
for %%d in (development staging production) do (
    if exist "%%d" (
        if NOT "%desired_dir_name%"=="%%d" (
            echo Renaming %%d to %desired_dir_name%
            git mv "%%d" "%desired_dir_name%" >nul 2>&1
        )
    )
)
