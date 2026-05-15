@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
set "LOG_FILE=%SCRIPT_DIR%packer_debug.log"

cd /d "%SCRIPT_DIR%"
if errorlevel 1 exit /b 1

echo [build] Working directory: %CD%
echo [build] Debug log: %LOG_FILE%

echo.>> "%LOG_FILE%"
echo ============================================================>> "%LOG_FILE%"
echo build-debug.bat started at %DATE% %TIME%>> "%LOG_FILE%"
echo ============================================================>> "%LOG_FILE%"

echo [build] Running packer validate ...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "$log = '%LOG_FILE%'; $enc = [Text.UTF8Encoding]::new($false); packer validate . 2>&1 | ForEach-Object { $line = $_.ToString(); Write-Host $line; [IO.File]::AppendAllText($log, $line + [Environment]::NewLine, $enc) }; exit $LASTEXITCODE"
if errorlevel 1 (
  echo [build] packer validate failed. Build aborted.
  echo [build] packer validate failed at %DATE% %TIME%>> "%LOG_FILE%"
  exit /b 1
)

echo [build] packer validate passed.
echo [build] Starting packer build with debug logging appended...

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "$log = '%LOG_FILE%'; $enc = [Text.UTF8Encoding]::new($false); $env:PACKER_LOG='1'; Remove-Item Env:PACKER_LOG_PATH -ErrorAction SilentlyContinue; packer build . 2>&1 | ForEach-Object { $line = $_.ToString(); Write-Host $line; [IO.File]::AppendAllText($log, $line + [Environment]::NewLine, $enc) }; exit $LASTEXITCODE"
set "BUILD_EXIT=%ERRORLEVEL%"

echo [build] packer build exited with code %BUILD_EXIT%.
echo build-debug.bat finished at %DATE% %TIME% with exit code %BUILD_EXIT%>> "%LOG_FILE%"

exit /b %BUILD_EXIT%
