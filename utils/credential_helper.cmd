@echo off
set /p req=
echo %req% | prebuilts\python\windows-x86\python.exe build\bazel\utils\cred_helper.py %*
