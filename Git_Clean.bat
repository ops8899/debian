@echo off
REM ��ȡ Git.env �ļ��еĻ�������
for /f "tokens=1,2 delims==" %%a in ('type Git.env') do (
    set %%a=%%b
)

REM ����һ���µ���ʱĿ¼
mkdir temp_repo
cd temp_repo

REM ��ʼ���µı��زֿ�
git init

REM ���Զ�ֿ̲��ַ
git remote add origin https://%GITHUB_USERNAME%:%GITHUB_TOKEN%@github.com/%GITHUB_USERNAME%/%REPO%.git

REM �������л����յ� main ��֧
git checkout --orphan main

REM ɾ�������ļ�
git rm -rf . > nul 2>&1

REM ȷ������Ŀ¼Ϊ��
del /F /Q .* > nul 2>&1
del /F /Q * > nul 2>&1

REM ����һ�����ύ
git commit --allow-empty -m "Empty"

REM ǿ�����Ϳշ�֧
git push -f origin main

REM �����ϼ�Ŀ¼
cd ..

REM ɾ����ʱĿ¼
rmdir /S /Q temp_repo
rmdir /S /Q .git

echo GitHub �ֿ�����ȫ��գ����κ��ύ��¼���ļ�������������˳�...
timeout /t 10
exit /b 0
