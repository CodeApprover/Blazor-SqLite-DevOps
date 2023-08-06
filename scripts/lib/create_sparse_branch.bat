@echo off
setlocal EnableDelayedExpansion

REM Move to parent directory
if "%~dp0"=="%~dp0scripts\" (
    pushd "%~dp0"
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

REM Move to repository directory
pushd "%~dp0.."

set "branch_created=0"
set "remote_created=0"
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
                set "remote_created=1"
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
    set "branch_created=1"
)

REM Display results
call :displayResults

REM Return to the original directory
popd

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
if "!branch_created!"=="1" (
    echo - Local branch %branch% has been created locally.
) else (
    echo - No local branch actions were taken.
)
if "!remote_created!"=="1" (
     echo - Remote branch %branch% was created.
) else (
    echo - No remote branch actions were taken.
)
echo =======================================================================
echo.
goto :eof
