@echo off
REM ��ȡ Git.env �ļ��еĻ�������
for /f "tokens=1,2 delims==" %%a in ('type Git.env') do (
    set %%a=%%b
)


REM ��ʼ�����زֿ�
git init

REM ���Զ�ֿ̲��ַ
git remote add origin https://%GITHUB_USERNAME%:%GITHUB_TOKEN%@github.com/%GITHUB_USERNAME%/%REPO%.git

REM �������л��� main ��֧
git checkout -b main

REM ��������ļ����ݴ���
git add .

REM �ύ�ļ������زֿ�
git commit -m "��ʼ���ύ"

REM ���͵�Զ�ֿ̲�� main ��֧
git push -f -u origin main

timeout /t 10
exit /b 0
