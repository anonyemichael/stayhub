@echo off
SET "APP_PATH=%~dp0runner\Release\stayhub.exe"
IF NOT EXIST "%APP_PATH%" (
    ECHO executable not found at %APP_PATH%
    ECHO Please build the app in release mode first: flutter build windows
    PAUSE
    EXIT /B
)

SET "SCHEME=stayhub"
SET "HKCU_Key=HKCU\Software\Classes\%SCHEME%"

REM Create the protocol key
REG ADD "%HKCU_Key%" /ve /d "URL:StayHub Protocol" /f
REG ADD "%HKCU_Key%" /v "URL Protocol" /d "" /f
REG ADD "%HKCU_Key%\DefaultIcon" /ve /d "\"%APP_PATH%\",0" /f
REG ADD "%HKCU_Key%\shell\open\command" /ve /d "\"%APP_PATH%\" \"%%1\"" /f

ECHO Successfully registered %SCHEME%:// protocol!
PAUSE
