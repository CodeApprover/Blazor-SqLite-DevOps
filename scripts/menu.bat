@echo off
setlocal EnableDelayedExpansion

REM Ensure we are in the top directory
if "%~dp0"=="%~dp0scripts\lib\" (
    pushd "..\.."
) else if "%~dp0"=="%~dp0scripts\" (
    pushd ".."
)

REM Define a variable for the valid environment options
set "valid_branches=code-development code-staging code-production"
set "branch=%~1"

REM Display description
call :displayDescription

REM Check if an argument is provided
if "%branch%"=="" (
    echo.
    echo Usage: %~nx0 ^<branch_name^>
    echo Available branches:
    echo %valid_branches%
    echo.
    exit /b 1
)

REM Check if the argument is one of the valid branches
set "valid=0"
for %%e in (%valid_branches%) do (
    if /i "%branch%"=="%%e" (
        set "valid=1"
    )
)

REM Prompt valid branches
if !valid! equ 0 (
    echo.
    echo Invalid branch requested.
    echo Please use one of the following options:
    echo %valid_branches%
    echo.
    exit /b 1
)

REM Check out the appropriate branch
if /i "%branch%"=="main" (
    git checkout main
) else (
    REM Check if the branch exists on the remote
    git ls-remote --exit-code --heads origin %branch% >nul 2>&1
    if errorlevel 1 (
        REM Branch does not exist on the remote, create it locally
        git checkout -b %branch% 2>nul
        if errorlevel 1 (
            echo The remote branch %branch% exists. It won't be overwritten, it will be cloned.
        ) else (
            REM Push the new branch to the remote only if it's code-development
            if /i "%branch%"=="code-development" (
                git push -u origin %branch%
            ) else (
                echo Remote branch creation for %branch% is managed by GitHub Actions.
            )
        )
    ) else (
        REM Branch exists on the remote, delete local branch if it exists
        git branch -D %branch% 2>nul
        REM Check out the remote branch
        git checkout -b %branch% origin/%branch%
    )
)

REM Rename directory if needed
call :renameDirectory

REM Display results
call :displayResults

endlocal
exit /b 0

:displayDescription
(
    echo.
    echo =======================================================================
    echo  - Create Sparse Branch manages Git branches for:
    echo  - %valid_branches%
    echo.
    echo - If a branch doesn't exist locally, it's created.
    echo - Existing local branches are replaced by their remote counterparts.
    echo.
    echo - Only 'code-development' can be created remotely.
    echo - if 'code-development' exists remotely, the local is
    echo - replaced by its remote counterpart.
    echo.
    echo - All other remote branch creation is managed by GitHub Actions.
    echo.
    echo  - WARNING: Use with caution.
    echo =======================================================================
    echo.
)
cls
goto :eof

:displayResults
echo.
echo =======================================================================
echo Results:
echo.
echo - Local branch %branch% has been created locally.
echo - Remote branch %branch% was created.
echo =======================================================================
echo.
goto :eof

:renameDirectory
REM Determine the desired directory name based on the branch
if /i "%branch%"=="code-development" set "desired_dir_name=development"
if /i "%branch%"=="code-staging" set "desired_dir_name=staging"
if /i "%branch%"=="code-production" set "desired_dir_name=production"

REM Iterate through possible directory names and rename if necessary
for %%d in (development staging production) do (
    if exist "%%d" (
        if NOT "%desired_dir_name%"=="%%d" (
            echo Renaming %%d to %desired_dir_name%
            ren "%%d" "%desired_dir_name%"
        )
    )
)
goto :eof
