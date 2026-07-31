@echo off

set project_root=%~dp0%
set build_folder=%project_root%\build\

set "time="
if exist "C:\apps\ntime.exe" set "time=C:\apps\ntime.exe"

if not exist %build_folder% (mkdir %build_folder%)

pushd %build_folder%
  %time% odin build .. -out:main.exe -subsystem:windows -debug
  IF %errorlevel% NEQ 0 (popd && goto end)

  %time% .\main.exe
  IF %errorlevel% NEQ 0 (popd && goto end)
popd

:end
exit /B %errorlevel%