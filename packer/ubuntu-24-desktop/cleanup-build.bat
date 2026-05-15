@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
set "OUTPUT_DIR=%SCRIPT_DIR%output"

echo [cleanup] Stop VMware VMs under output directory...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "$output = [IO.Path]::GetFullPath('%OUTPUT_DIR%');" ^
  "$vmrun = 'C:\Program Files (x86)\VMware\VMware Workstation\vmrun.exe';" ^
  "if (Test-Path -LiteralPath $output) {" ^
  "  Get-ChildItem -LiteralPath $output -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -ieq '.vmx' } | ForEach-Object {" ^
  "    Write-Host ('[cleanup] vmrun stop {0}' -f $_.FullName);" ^
  "    if (Test-Path -LiteralPath $vmrun) { & $vmrun -T ws stop $_.FullName hard 2>$null }" ^
  "  }" ^
  "}"

echo [cleanup] Stop Packer build processes...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "$names = @('packer','packer-plugin-vmware_v1.2.0_x5.0_windows_amd64','vmrun');" ^
  "Get-Process | Where-Object { $names -contains $_.ProcessName } | ForEach-Object {" ^
  "    Write-Host ('[cleanup] stopping {0} pid={1}' -f $_.ProcessName, $_.Id);" ^
  "    Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue" ^
  "}"

echo [cleanup] Delete virtual machine files under output...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "$output = [IO.Path]::GetFullPath('%OUTPUT_DIR%');" ^
  "$root = [IO.Path]::GetFullPath('%SCRIPT_DIR%');" ^
  "if (-not $output.StartsWith($root, [StringComparison]::OrdinalIgnoreCase)) { throw 'Refusing to delete outside script directory' }" ^
  "if (Test-Path -LiteralPath $output) {" ^
  "  Get-ChildItem -LiteralPath $output -Force | ForEach-Object {" ^
  "    Write-Host ('[cleanup] deleting {0}' -f $_.FullName);" ^
  "    Remove-Item -LiteralPath $_.FullName -Recurse -Force" ^
  "  }" ^
  "} else {" ^
  "  New-Item -ItemType Directory -Path $output | Out-Null" ^
  "  Write-Host ('[cleanup] created output directory {0}' -f $output)" ^
  "}"

echo [cleanup] Done.
endlocal
