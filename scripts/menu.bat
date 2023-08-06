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
echo main
echo ======================================
echo.
echo [1] Create Sparse Branch
echo [2] Reset All Branches
echo [3] Reset Main Branch
echo [4] Reset Sparse Branch
echo [5] Switch User
echo [6] Display Directory Structure
echo [7] Exit
echo.
set /p choice="Enter choice: "

if "%choice%"=="1" goto create_sparse_branch
if "%choice%"=="2" goto reset_all_branches
if "%choice%"=="3" goto reset_main_branch
if "%choice%"=="4" goto reset_sparse_branch
if "%choice%"=="5" goto switch_user
if "%choice%"=="6" goto display_structure
if "%choice%"=="7" cls & goto :eof

:create_sparse_branch
set /p branch=Enter branch name: 
call "%scripts_dir%\lib\create_sparse_branch.bat" %branch%
pause
goto menu

:reset_all_branches
call "%scripts_dir%\lib\reset_all_branches.bat"
pause
goto menu

:reset_main_branch
call "%scripts_dir%\lib\reset_main_branch.bat"
pause
goto menu

:reset_sparse_branch
set /p branch=Enter branch name: 
call "%scripts_dir%\lib\reset_sparse_branch.bat" %branch%
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

REM Return to the original directory
popd
