@echo off
REM 读取 Git.env 文件中的环境变量
for /f "tokens=1,2 delims==" %%a in ('type Git.env') do (
    set %%a=%%b
)

REM 创建一个新的临时目录
mkdir temp_repo
cd temp_repo

REM 初始化新的本地仓库
git init

REM 添加远程仓库地址
git remote add origin https://%GITHUB_USERNAME%:%GITHUB_TOKEN%@github.com/%GITHUB_USERNAME%/%REPO%.git

REM 创建并切换到空的 main 分支
git checkout --orphan main

REM 删除所有文件
git rm -rf . > nul 2>&1

REM 确保工作目录为空
del /F /Q .* > nul 2>&1
del /F /Q * > nul 2>&1

REM 创建一个空提交
git commit --allow-empty -m "Empty"

REM 强制推送空分支
git push -f origin main

REM 返回上级目录
cd ..

REM 删除临时目录
rmdir /S /Q temp_repo
rmdir /S /Q .git

echo GitHub 仓库已完全清空（无任何提交记录和文件）。按任意键退出...
timeout /t 10
exit /b 0
