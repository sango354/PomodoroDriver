@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
set "REPO_ROOT=%SCRIPT_DIR%.."
set "IMPORT_SCRIPT=%SCRIPT_DIR%import_google_sheet_text.py"
set "CONFIG=%SCRIPT_DIR%text_data_config.json"

cd /d "%REPO_ROOT%"

where py >nul 2>nul
if %ERRORLEVEL%==0 (
  py -3 "%IMPORT_SCRIPT%" --config "%CONFIG%" %*
) else (
  python "%IMPORT_SCRIPT%" --config "%CONFIG%" %*
)

set "EXIT_CODE=%ERRORLEVEL%"
echo.
if not "%EXIT_CODE%"=="0" (
  echo Import failed with exit code %EXIT_CODE%.
) else (
  echo Import finished.
)
pause
exit /b %EXIT_CODE%
