@echo off

REM 读取 Git.env 文件中的环境变量
for /f "tokens=1,2 delims==" %%a in ('type Git.env') do (
    set %%a=%%b
)

REM 初始化本地仓库
git init

REM 添加远程仓库地址
git remote add origin https://github.com/%GITHUB_USERNAME%/%REPO%.git

REM 获取远程仓库的内容
git fetch origin

REM 检出远程的 main 分支
git checkout -t origin/main

REM 等待 10 秒
timeout /t 10

REM 退出脚本
exit /b 0
