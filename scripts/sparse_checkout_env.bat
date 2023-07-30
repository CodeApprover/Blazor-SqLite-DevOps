@echo off
setlocal EnableDelayedExpansion

if "%~1" neq "" (
    git sparse-checkout set --skip-checks code-%~1
) else (
    echo Usage: %0 ^<environment^>
    exit /b 1
)

cd ..

if exist .git\info\sparse-checkout (
    del .git\info\sparse-checkout
)

if "%~1" == "main" (
    git checkout main
) else (
    git checkout code-%~1
    git sparse-checkout disable
    git sparse-checkout set code-%~1
    git sparse-checkout reapply
)

echo tests/* >> .git\info\sparse-checkout
echo docs/* >> .git\info\sparse-checkout

endlocal
