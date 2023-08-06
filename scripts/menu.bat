@echo off

REM Ensure we are in the top directory
if "%~dp0"=="%~dp0scripts\lib\" (
    pushd "..\.."
) else if "%~dp0"=="%~dp0scripts\" (
    pushd ".."
)
set "scripts_dir=%~dp0"

:menu
cls
echo ======================================
echo Main Menu
echo ======================================
echo.
echo Valid Branches
echo ======================================
echo.
echo code-development
echo code-staging
echo code-production
echo ======================================
echo.
echo [1] Create Branch
echo [2] Switch User
echo [3] Display Directory Structure
echo [4] Exit
echo.
set /p choice="Enter choice: "

if "%choice%"=="1" goto create_branch
if "%choice%"=="2" goto switch_user
if "%choice%"=="3" goto display_structure
if "%choice%"=="4" cls & goto :eof

:create_branch
set /p branch=Enter branch name: 
call "%scripts_dir%\lib\create_branch.bat" %branch%
pause
goto menu

:switch_user
call "%scripts_dir%\lib\switch_user.bat"
pause
goto menu

:display_structure
echo .
pushd "%scripts_dir%"
echo scripts directory:
dir /b /s /a-d
echo.
pushd "%scripts_dir%\lib"
echo lib directory:
dir /b /s /a-d
echo.
popd & popd
pause
goto menu

REM Return to the starting directory
popd
