@echo off
set TARGET_DIR=..
set TARGET_FILE=%TARGET_DIR%\qinbao.zip

mkdir "%TARGET_DIR%"
del /q "%TARGET_FILE%"

"C:\Program Files\7-Zip\7z.exe" a -tzip "%TARGET_FILE%" -r .\*


timeout /t 10
exit /b 0
