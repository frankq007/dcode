@echo off
set "JAVA_HOME=d:\Program Files\Huawei\DevEco Studio\tools\java\jbr"
set "NODE_HOME=d:\Program Files\Huawei\DevEco Studio\tools\node"
set "DEVECO_SDK_HOME=D:\sdk"
set "PATH=%NODE_HOME%;%JAVA_HOME%\bin;%PATH%"
cd /d D:\code\dcode\app
call "d:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat" clean
call "d:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat" assembleHap -p product=default -p module=entry@default --no-daemon

