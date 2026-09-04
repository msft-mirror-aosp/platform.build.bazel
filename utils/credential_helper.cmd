@echo off
if exist "%~dp0..\..\..\prebuilts\python\windows-x86\python.exe" (
    "%~dp0..\..\..\prebuilts\python\windows-x86\python.exe" "%~dp0cred_helper.py" %*
) else (
    prebuilts\python\windows-x86\python.exe "%~dp0cred_helper.py" %*
)
