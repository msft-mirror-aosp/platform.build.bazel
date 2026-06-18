@echo off
set /p req=
echo %req% | prebuilts\python\windows-x86\x64\python.exe build\bazel\tools\credhelper.py %*