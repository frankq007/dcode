Set objShell = CreateObject("WScript.Shell")
objShell.Run "cmd /c cd /d D:\code\dcode\gateway && ""C:\Program Files\nodejs\node.exe"" --import file:///D:/code/dcode/gateway/node_modules/tsx/dist/loader.mjs src/index.ts > D:\code\dcode\gw-stdout.log 2> D:\code\dcode\gw-stderr.log", 0, False
