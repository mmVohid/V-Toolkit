@echo off
rem ======================================================================
rem  lib\core.bat  -  umumiy yordamchi funksiyalar (TOOLKIT va barcha modullar uchun)
rem
rem  Ishlatish:   call "%TK_C%" :OK "matn"
rem               call "%TK_C%" :ASK_YN "Davom etilsinmi?"   (0 = Ha, 1 = Yo'q)
rem
rem  Matn qoidasi: faqat ASCII; matn ichida  !  %  "  belgilari bo'lmasin.
rem  Kerakli o'zgaruvchilar (TOOLKIT.bat o'rnatadi): C_* ranglar, TK_LANG,
rem  TK_LOGFILE, TK_DATE, TK_MOD, TK_ADMIN, TK_SELF
rem ======================================================================
if "%~1"=="" exit /b 0
call %*
exit /b

rem ======================================================================
rem  Chiqarish yordamchilari
rem ======================================================================
:HEADER
setlocal DisableDelayedExpansion
set "_m=%~1"
setlocal EnableDelayedExpansion
cls
echo.
echo   %C_C%========================================================================%C_0%
echo     %C_W%!_m!%C_0%
echo   %C_C%========================================================================%C_0%
echo.
endlocal
endlocal
exit /b 0

:_PRINT
rem %1 = rang   %2 = belgi   %3 = matn
setlocal DisableDelayedExpansion
set "_m=%~3"
setlocal EnableDelayedExpansion
echo   %~1%~2%C_0%  !_m!
endlocal
endlocal
exit /b 0

:OK
call :_PRINT "%C_G%" "[+]" "%~1"
call :LOG OK "%~1"
exit /b 0

:ERR
call :_PRINT "%C_R%" "[x]" "%~1"
call :LOG ERROR "%~1"
exit /b 0

:WARN
call :_PRINT "%C_Y%" "[*]" "%~1"
call :LOG WARN "%~1"
exit /b 0

:INFO
call :_PRINT "%C_C%" "[i]" "%~1"
exit /b 0

rem ======================================================================
rem  Savol: Y/N.  Qaytaradi: 0 = Ha, 1 = Yo'q (yoki Ctrl+C)
rem ======================================================================
:ASK_YN
setlocal DisableDelayedExpansion
set "_m=%~1"
setlocal EnableDelayedExpansion
echo.
choice /c YN /n /m "  !_m! [Y/N]: "
set "_rc=!errorlevel!"
if "!_rc!"=="1" (set "_rc=0") else (set "_rc=1")
endlocal & endlocal & exit /b %_rc%

rem ======================================================================
rem  Hisob-kitob: C = bekor qilish (shutdown /a), vaqt tugasa = davom etish
rem  Qaytaradi: 0 = davom etdi, 1 = bekor qilindi
rem ======================================================================
:COUNTDOWN
echo.
choice /c CX /n /t %~1 /d X /m "  %T_CD% "
if errorlevel 2 exit /b 0
shutdown /a >nul 2>&1
echo.
call :OK "%T_CANCELLED%"
call :LOG ACTION "shutdown cancelled by user"
exit /b 1

rem ======================================================================
rem  Log:  call "%TK_C%" :LOG DARAJA "xabar"
rem  Format: YYYY-MM-DD HH:MM:SS [DARAJA] [modul] xabar
rem ======================================================================
:LOG
if not defined TK_LOGFILE exit /b 0
setlocal DisableDelayedExpansion
set "_m=%~2"
set "_t=%TIME: =0%"
setlocal EnableDelayedExpansion
2>nul >>"!TK_LOGFILE!" echo !TK_DATE! !_t:~0,8! [%~1] [!TK_MOD!] !_m!
endlocal
endlocal
exit /b 0

rem ======================================================================
rem  Administrator huquqi (lazy elevation)
rem  call "%TK_C%" :NEED_ADMIN buyruq_nomi
rem  Qaytaradi: 0 = admin bor, davom eting;  1 = yo'q (so'raldi / bekor qilindi)
rem ======================================================================
:NEED_ADMIN
if "%TK_ADMIN%"=="1" exit /b 0
call :WARN "%T_NEEDADMIN%"
call :ASK_YN "%T_RELAUNCH_ASK%"
if errorlevel 1 exit /b 1
call :RELAUNCH "%~1"
exit /b 1

rem  Shu skriptni admin sifatida yangi oynada, berilgan buyruq bilan ochadi.
rem  Yo'l va argumentlar muhit o'zgaruvchisi orqali beriladi (qo'shtirnoq muammosi yo'q).
:RELAUNCH
setlocal DisableDelayedExpansion
set "TK_RL_ARGS=%~1 --lang %TK_LANG%"
if defined NO_COLOR set "TK_RL_ARGS=%TK_RL_ARGS% --no-color"
powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath $env:TK_SELF -ArgumentList $env:TK_RL_ARGS -Verb RunAs" >nul 2>&1
if errorlevel 1 (
    call :ERR "%T_RELAUNCH_FAIL%"
) else (
    call :OK "%T_RELAUNCH_OK%"
    call :LOG ACTION "relaunch as admin: %~1"
)
endlocal
exit /b 0

rem ======================================================================
rem  Umumiy matnlar
rem ======================================================================
:LANG_UZ
set "T_PRESS=Menyuga qaytish uchun istalgan tugmani bosing..."
set "T_CD=Bekor qilish uchun C tugmasini bosing."
set "T_CANCELLED=Bekor qilindi."
set "T_NEEDADMIN=Bu amal Administrator huquqini talab qiladi."
set "T_RELAUNCH_ASK=Administrator rejimida yangi oynada ochilsinmi?"
set "T_RELAUNCH_OK=Yangi (administrator) oyna ochildi. Amalni o'sha oynada davom ettiring."
set "T_RELAUNCH_FAIL=Administrator huquqi berilmadi yoki oyna ochilmadi."
exit /b 0

:LANG_EN
set "T_PRESS=Press any key to return to the menu..."
set "T_CD=Press C to cancel."
set "T_CANCELLED=Cancelled."
set "T_NEEDADMIN=This action requires administrator rights."
set "T_RELAUNCH_ASK=Open a new window as administrator?"
set "T_RELAUNCH_OK=A new (administrator) window was opened. Continue the action there."
set "T_RELAUNCH_FAIL=Administrator rights were denied or the window could not be opened."
exit /b 0
