@echo off
setlocal

set email=eatdirtfool@pm.me
set user1=code-backups
set user2=codeapprover

for /f "delims=" %%a in ('git config --global user.name') do set currentuser=%%a

if "%currentuser%"=="%user1%" (
  set newuser=%user2%
) else (
  set newuser=%user1%
)

git config --global user.name "%newuser%"
if %ERRORLEVEL% neq 0 (
  echo Failed to switch the user to %newuser%.
  exit /b 1
)

git config --global user.email "%email%"
if %ERRORLEVEL% neq 0 (
  echo Failed to switch the email to %email%.
  exit /b 1
)

echo Successfully switched to user %newuser%.

endlocal

exit /b 0
