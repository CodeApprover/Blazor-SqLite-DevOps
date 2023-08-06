@echo off
setlocal EnableDelayedExpansion

echo ########################################################################
echo Setup
echo ########################################################################

echo Ensure the script is executed from the top directory of the repository.
if "%~dp0"=="%~dp0scripts\lib\" (
    pushd "..\.."
) else if "%~dp0"=="%~dp0scripts\" (
    pushd ".."
)

echo Set the main directory of the repository.
set "REPO_DIR=%CD%"

echo Define the valid branch names and capture the branch name provided as an argument.
set "valid_branches=code-development code-staging code-production"
set "branch=%~1"

echo Display a script description and check if the provided branch name is valid.
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

echo Fetch updates from all remote branches.
git fetch --all

echo Check if a branch name was provided as an argument.
if "%branch%"=="" (
    echo.
    echo Usage: %~nx0 ^<branch_name^>
    echo Available branches:
    echo %valid_branches%
    echo.
    exit /b 1
)

echo Validate the provided branch name against the list of valid branches.
set "valid=0"
for %%e in (%valid_branches%) do (
    if /i "%branch%"=="%%e" (
        set "valid=1"
    )
)

echo If the provided branch name is invalid, display an error message.
if !valid! equ 0 (
    echo.
    echo Invalid branch requested.
    echo Please use one of the following options:
    echo %valid_branches%
    echo.
    exit /b 1
)

echo Define a temporary branch name and directory for operations.
set "temp_dir=..\temp_dir"

echo If temp_dir exists, delete it. Then, create a fresh temp_dir.
if exist "%tempDir%" rmdir /s /q "%tempDir%"
mkdir "%tempDir%"

echo If temp_branch exists locally, delete it. Then, create and checkout a new temp_branch.
git rev-parse --verify temp_branch >nul 2>&1
if not errorlevel 1 git branch -D temp_branch
git checkout -b temp_branch

echo ########################################################################
echo Create Empty Requested Branch Locally
echo ########################################################################

echo Check if the requested branch exists locally.
git rev-parse --verify %branch% 2>nul
set branchExistsLocal=!errorlevel!

echo If the branch exists locally, checkout the branch, stash any changes and delete all files associated with it.
if !branchExistsLocal! equ 0 (
    git checkout %branch%
    git stash push -u -m "Stash before deleting %branch%"
    echo "Changes have been stashed with the message: Stash before deleting %branch%."
    echo "Please note this for future reference."
    timeout /t 5
    git rm -rf %REPO_DIR%/*
    git branch -D %branch%
) else (
    echo If the branch doesn't exist locally, create an empty orphan branch with that name.
    git checkout --orphan %branch%
    git rm -rf .
)

echo Switch back to the temporary branch for further operations.
git checkout %temp_branch%

echo ########################################################################
echo Populate Requested Branch Locally
echo ########################################################################

echo Check if the requested branch exists on the remote.
git ls-remote --exit-code --heads origin %branch%

echo If the branch doesn't exist remotely, clone the main branch from the remote repository into temp_dir.
if errorlevel 1 (
    for /f "tokens=*" %%i in ('git remote get-url origin') do set "remoteURL=%%i"
    echo Cloning from remote URL: "%remoteURL%"
    git clone "%remoteURL%" -b main "%temp_dir%"
    if errorlevel 1 echo Failed to clone main branch.
) else ( 
    echo If the branch exists remotely, clone that specific branch into temp_dir.
    git clone "%remoteURL%" -b %branch% %temp_dir%
    if errorlevel 1 echo Failed to clone branch %branch%.
)

echo After cloning, checkout the %branch% locally and copy the contents of temp_dir to the current directory (REPO_DIR).
git checkout %branch%
xcopy /E /I /Y "%temp_dir%\*" "%REPO_DIR%"

echo ########################################################################
echo Rename Directory Based on Branch
echo ########################################################################

echo Determine the desired directory name based on the branch.
if /i "%branch%"=="code-development" set "desired_dir_name=development"
if /i "%branch%"=="code-staging" set "desired_dir_name=staging"
if /i "%branch%"=="code-production" set "desired_dir_name=production"

echo Rename directories as needed based on the branch name.
for %%d in (development staging production) do (
    if exist "%%d" (
        if NOT "%desired_dir_name%"=="%%d" (
            echo Renaming %%d to %desired_dir_name%
            git mv "%%d" "%desired_dir_name%" 2>&1
        )
    )
)

echo Cleanup: Check if temp_dir exists before trying to delete it.
if exist "%temp_dir%" (
    git rm -rf %temp_dir%/*
    git clean %temp_dir% -fd
    rmdir /s /q "%temp_dir%"
)
git branch -D %temp_branch% 2>nul
