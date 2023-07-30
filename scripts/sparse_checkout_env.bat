@echo off
setlocal EnableDelayedExpansion

REM Move to main directory
cd ..

REM Check if sparse-checkout file exists before removing
if exist .git\info\sparse-checkout (
    del .git\info\sparse-checkout
)

REM Checkout required branch
if "%~1" == "main" (
    git checkout main
) else (
    git checkout code-"%~1"
)

REM Disable sparse-checkout if enabled
git sparse-checkout disable

REM Set sparse-checkout configuration with argument directory
if "%~1" neq "" (
    git sparse-checkout set --skip-checks "%~1"
) else (
    echo Usage: %0 ^<directory^>
    exit /b 1
)

REM Reapply sparse-checkout specifications
git sparse-checkout reapply

REM set sparse-checkout file
if "%~1" == "main" (
    git read-tree -mu HEAD
)

endlocal
