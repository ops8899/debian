@echo off
set TARGET_DIR=dist
set TARGET_FILE=%TARGET_DIR%\debian.zip

mkdir "%TARGET_DIR%"
del /q "%TARGET_FILE%"

"C:\Program Files\7-Zip\7z.exe" a -tzip "%TARGET_FILE%" -r system\*


timeout /t 10
exit /b 0
