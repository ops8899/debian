@echo off
REM 读取 Git.env 文件中的环境变量
for /f "tokens=1,2 delims==" %%a in ('type Git.env') do (
    set %%a=%%b
)


REM 初始化本地仓库
git init

REM 添加远程仓库地址
git remote add origin https://%GITHUB_USERNAME%:%GITHUB_TOKEN%@github.com/%GITHUB_USERNAME%/%REPO%.git

REM 创建并切换到 main 分支
git checkout -b main

REM 添加所有文件到暂存区
git add .

REM 提交文件到本地仓库
git commit -m "初始化提交"

REM 推送到远程仓库的 main 分支
git push -f -u origin main

timeout /t 10
exit /b 0
