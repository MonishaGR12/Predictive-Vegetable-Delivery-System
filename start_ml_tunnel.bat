@echo off
cd /D C:\Users\Monisha\AndroidStudioProjects\Gruno
"C:\Users\Monisha\AndroidStudioProjects\Gruno\tools\cloudflared.exe" tunnel --protocol http2 --no-autoupdate --loglevel info --url http://127.0.0.1:5000
