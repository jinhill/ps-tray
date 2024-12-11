## build 
download sing-box.exe from github repo, rename sing-box.exe to sing-box-latest.exe, and place it in the same path as this script.  
in powershell  
```
Install-Module -Name ps2exe -RequiredVersion 1.0.13
ps2exe .\sing-box-tray.ps1 .\sing-box-tray.exe -noConsole -icon "sing-box.ico" -requireAdmin
```
