@echo off
rem ======================================================================
rem  Vohid TOOLKIT  -  Windows SysAdmin + Backend/DevOps CLI
rem
rem  Tuzilma:
rem    TOOLKIT.bat          menyu, til, lazy admin, buyruq dispetcheri
rem    lib\core.bat         HEADER / OK / ERR / WARN / INFO / ASK_YN / COUNTDOWN / LOG
rem    lib\core.ps1         PowerShell modullari uchun juft yordamchilar
rem    lib\init.ps1         log papkasi, eski loglarni tozalash, sana
rem    modules\*.bat/.ps1   modullar: .bat = UI + LANG_UZ/LANG_EN, .ps1 = mantiq
rem
rem  CLI:  TOOLKIT.bat [buyruq] [--lang UZ|EN] [--no-color]
rem        buyruqlar: cmd ps path devmgr scan activation bios shutdown winget ports env changelog about
rem        env:       TOOLKIT.bat env [papka] [--ci]   (--ci: chiqish kodi 0/1, rangsiz, savolsiz)
rem
rem  Matn qoidasi: ASCII; matn ichida  !  %  "  bo'lmasin.
rem  Fayl CRLF qator oxiri bilan saqlanishi shart (.gitattributes).
rem ======================================================================
setlocal DisableDelayedExpansion
set "TK_ROOT=%~dp0"
if "%TK_ROOT:~-1%"=="\" set "TK_ROOT=%TK_ROOT:~0,-1%"
set "TK_SELF=%~f0"
set "TK_C=%TK_ROOT%\lib\core.bat"
set "TK_VER=2.1.0"
set "TK_CWD=%CD%"
set "TK_CMD="
set "TK_LANG_ARG="
set "TK_ONESHOT="
set "TK_ARG="
set "TK_CI="

rem ----------------------------------------------------------------------
rem  Argumentlar (delayed expansion o'chiq: yo'lda '!' bo'lsa ham xavfsiz)
rem ----------------------------------------------------------------------
:PARSE_ARGS
if "%~1"=="" goto ARGS_DONE
if /i "%~1"=="--no-color" set "NO_COLOR=1" & shift & goto PARSE_ARGS
if /i "%~1"=="--lang" set "TK_LANG_ARG=%~2" & shift & shift & goto PARSE_ARGS
if /i "%~1"=="--ci" set "TK_CI=1" & set "NO_COLOR=1" & shift & goto PARSE_ARGS
if not defined TK_CMD set "TK_CMD=%~1" & shift & goto PARSE_ARGS
if not defined TK_ARG set "TK_ARG=%~1"
shift
goto PARSE_ARGS
:ARGS_DONE

setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul
title Vohid TOOLKIT v!TK_VER!
mode con cols=84 >nul 2>&1
pushd "!TK_ROOT!" 2>nul

if not exist "!TK_C!" (
    echo.
    echo   [x] lib\core.bat topilmadi / lib\core.bat not found.
    echo       Toolkit papkasini to'liq nusxalang / Copy the whole Toolkit folder.
    echo.
    pause
    exit /b 1
)

rem ======================================================================
rem  Boshlang'ich sozlamalar
rem ======================================================================
:INIT
set "TK_MOD=main"
set "TK_EMPTY=0"
set "TK_BAD=0"

rem --- Administrator holati (fltmc ishonchliroq; zaxira: net session) ---
set "TK_ADMIN=0"
fltmc >nul 2>&1 && set "TK_ADMIN=1"
if "!TK_ADMIN!"=="0" net session >nul 2>&1 && set "TK_ADMIN=1"

rem --- Ranglar: ANSI faqat Windows 10+ da; NO_COLOR / --no-color hurmat qilinadi ---
if not defined NO_COLOR (ver | findstr /c:"10.0." >nul || set "NO_COLOR=1")
if defined NO_COLOR goto COLOR_NONE
for /f %%a in ('echo prompt $E ^| cmd') do set "ESC=%%a"
set "C_0=!ESC![0m"
set "C_C=!ESC![96m"
set "C_G=!ESC![92m"
set "C_Y=!ESC![93m"
set "C_R=!ESC![91m"
set "C_D=!ESC![90m"
set "C_W=!ESC![97m"
goto COLOR_DONE
:COLOR_NONE
set "C_0="
set "C_C="
set "C_G="
set "C_Y="
set "C_R="
set "C_D="
set "C_W="
:COLOR_DONE

if "!TK_ADMIN!"=="1" (
    set "TK_ADM_TXT=%C_G%Admin: ON%C_0%"
    set "TK_ADM_SFX= (Admin)"
    set "TK_STAR="
) else (
    set "TK_ADM_TXT=%C_Y%Admin: OFF%C_0%"
    set "TK_ADM_SFX="
    set "TK_STAR= %C_Y%*%C_0%"
)

rem --- Til: lang.cfg (eski VohidToolkit.lang dan ko'chiriladi), --lang ustun ---
set "TK_CFGDIR=!LOCALAPPDATA!\VohidToolkit"
if not exist "!TK_CFGDIR!" md "!TK_CFGDIR!" >nul 2>&1
set "TK_CFG=!TK_CFGDIR!\lang.cfg"
set "TK_OLDCFG=!LOCALAPPDATA!\VohidToolkit.lang"
set "TK_LANG=UZ"
if exist "!TK_OLDCFG!" if not exist "!TK_CFG!" set /p TK_LANG=<"!TK_OLDCFG!"
if exist "!TK_CFG!" set /p TK_LANG=<"!TK_CFG!"
if defined TK_LANG_ARG set "TK_LANG=!TK_LANG_ARG!"
if /i "!TK_LANG!"=="EN" (set "TK_LANG=EN") else (set "TK_LANG=UZ")
call :LANG_!TK_LANG!
call "!TK_C!" :LANG_!TK_LANG!

rem --- Log: bir marta PowerShell (papka + 14 kundan eski loglarni tozalash + sana) ---
set "TK_DATE="
for /f "usebackq delims=" %%d in (`powershell -NoProfile -ExecutionPolicy Bypass -File "!TK_ROOT!\lib\init.ps1" 2^>nul`) do set "TK_DATE=%%d"
if not defined TK_DATE set "TK_DATE=0000-00-00"
set "TK_LOGFILE=!LOCALAPPDATA!\VohidToolkit\logs\toolkit-!TK_DATE!.log"
call "!TK_C!" :LOG INFO "start v!TK_VER! admin=!TK_ADMIN! lang=!TK_LANG!"

if defined TK_CMD set "TK_ONESHOT=1" & goto DISPATCH
goto MENU

rem ======================================================================
rem  Asosiy menyu
rem ======================================================================
:MENU
set "choice="
cls
echo.
echo   %C_C%========================================================================%C_0%
echo     %C_W%VOHID TOOLKIT%C_0% %C_D%v!TK_VER!%C_0%        %C_D%!T_SUB!%C_0%        %C_G%[!TK_LANG!]%C_0%
echo   %C_C%========================================================================%C_0%
echo     %C_D%PC: %COMPUTERNAME%   ^|   %USERNAME%   ^|%C_0% %TK_ADM_TXT%
echo.
echo     %C_D%!T_G1!%C_0%
echo     %C_G%[1]%C_0%   !T_M1!
echo     %C_G%[2]%C_0%   !T_M2!
echo     %C_G%[3]%C_0%   !T_M3!
echo     %C_G%[4]%C_0%   !T_M4!
echo.
echo     %C_D%!T_G2!%C_0%
echo     %C_G%[5]%C_0%   !T_M5!!TK_STAR!
echo     %C_G%[6]%C_0%   !T_M6!
echo     %C_G%[7]%C_0%   !T_M7!!TK_STAR!
echo     %C_G%[8]%C_0%   !T_M8!
echo.
echo     %C_D%!T_G3!%C_0%
echo     %C_G%[9]%C_0%   !T_M9!
echo     %C_G%[10]%C_0%  !T_M10!
echo     %C_G%[11]%C_0%  !T_M11!
echo     %C_G%[12]%C_0%  !T_M12!
echo.
echo   %C_D%------------------------------------------------------------------------%C_0%
echo     %C_C%[A]%C_0% !T_MA!      %C_C%[L]%C_0% !T_ML!      %C_C%[0]%C_0% !T_M0!
if "!TK_ADMIN!"=="0" echo     %C_D%* !T_ADMIN_NOTE!%C_0%
echo   %C_C%========================================================================%C_0%
echo.
set /p "choice=  %C_C%>>%C_0% "

set "choice=!choice:"=!"
set "choice=!choice: =!"
if not defined choice (
    rem  Kirish tugagan (EOF) bo'lsa cheksiz tsiklga tushmaslik uchun
    set /a TK_EMPTY+=1
    if !TK_EMPTY! GEQ 20 goto QUIT
    goto MENU
)
set "TK_EMPTY=0"

if "!choice!"=="1" goto T_CMD
if "!choice!"=="2" goto T_PS
if "!choice!"=="3" goto T_ENV
if "!choice!"=="4" goto T_DEV
if "!choice!"=="5" goto T_SCAN
if "!choice!"=="6" goto T_ACT
if "!choice!"=="7" goto T_BIOS
if "!choice!"=="8" goto T_OFF
if "!choice!"=="9" goto T_WG
if "!choice!"=="10" goto T_PORT
if "!choice!"=="11" goto T_DOTENV
if "!choice!"=="12" goto T_CHLOG
if /i "!choice!"=="a" goto T_ABOUT
if /i "!choice!"=="l" goto T_LANG
if "!choice!"=="0" goto QUIT
if /i "!choice!"=="exit" goto QUIT

echo.
call "!TK_C!" :ERR "!T_INVALID!"
rem  timeout.exe yo'naltirilgan stdin bilan ishlamaydi -> ping bilan kutamiz
ping -n 2 127.0.0.1 >nul 2>&1
set /a TK_BAD+=1
if !TK_BAD! GEQ 20 goto QUIT
goto MENU

rem ======================================================================
rem  CLI dispetcher:  TOOLKIT.bat <buyruq>
rem ======================================================================
:DISPATCH
call "!TK_C!" :LOG INFO "cli command=!TK_CMD!"
if /i "!TK_CMD!"=="cmd" goto T_CMD
if /i "!TK_CMD!"=="ps" goto T_PS
if /i "!TK_CMD!"=="path" goto T_ENV
if /i "!TK_CMD!"=="devmgr" goto T_DEV
if /i "!TK_CMD!"=="scan" goto T_SCAN
if /i "!TK_CMD!"=="activation" goto T_ACT
if /i "!TK_CMD!"=="bios" goto T_BIOS
if /i "!TK_CMD!"=="shutdown" goto T_OFF
if /i "!TK_CMD!"=="winget" goto T_WG
if /i "!TK_CMD!"=="ports" goto T_PORT
if /i "!TK_CMD!"=="env" goto T_DOTENV
if /i "!TK_CMD!"=="changelog" goto T_CHLOG
if /i "!TK_CMD!"=="about" goto T_ABOUT
echo.
call "!TK_C!" :ERR "!T_UNKNOWN! !TK_CMD!"
call "!TK_C!" :INFO "!T_USAGE!"
echo.
popd
exit /b 1

rem ======================================================================
rem  [1] [2] [3] [4]  Asboblar
rem ======================================================================
:T_CMD
call "!TK_C!" :LOG INFO "open cmd"
start "CMD!TK_ADM_SFX!" /d "!USERPROFILE!" cmd.exe
goto BACK

:T_PS
call "!TK_C!" :LOG INFO "open powershell"
start "PowerShell!TK_ADM_SFX!" /d "!USERPROFILE!" powershell.exe -NoLogo
goto BACK

:T_ENV
call "!TK_C!" :LOG INFO "open environment variables"
rundll32 sysdm.cpl,EditEnvironmentVariables
goto BACK

:T_DEV
call "!TK_C!" :LOG INFO "open device manager"
start "" devmgmt.msc
goto BACK

rem ======================================================================
rem  [5] Tizimni skanerlash (avval DISM, keyin SFC - to'g'ri tartib)
rem ======================================================================
:T_SCAN
call "!TK_C!" :NEED_ADMIN scan || goto BACK
call "!TK_C!" :HEADER "!T_M5!"
call "!TK_C!" :LOG ACTION "scan start (dism + sfc)"
call "!TK_C!" :INFO "[1/2] !T_SCAN1!"
echo.
dism /online /cleanup-image /restorehealth
set "RC1=!errorlevel!"
echo.
call "!TK_C!" :INFO "[2/2] !T_SCAN2!"
echo.
sfc /scannow
set "RC2=!errorlevel!"
echo.
call "!TK_C!" :LOG INFO "scan finished dism=!RC1! sfc=!RC2!"
if "!RC1!"=="0" if "!RC2!"=="0" goto SCAN_OK
call "!TK_C!" :WARN "!T_SCAN_WARN! [DISM !RC1!, SFC !RC2!]"
goto SCAN_END
:SCAN_OK
call "!TK_C!" :OK "!T_SCAN_DONE!"
:SCAN_END
call "!TK_C!" :INFO "!T_LOG! %windir%\Logs\CBS\CBS.log"
goto PAUSE_BACK

rem ======================================================================
rem  [6] Windows aktivatsiya holati
rem ======================================================================
:T_ACT
call "!TK_C!" :HEADER "!T_M6!"
cscript //nologo "%windir%\System32\slmgr.vbs" /xpr
echo.
call "!TK_C!" :INFO "!T_ACT_NOTE!"
call "!TK_C!" :ASK_YN "!T_ACT_OPEN!"
if not errorlevel 1 start "" ms-settings:activation
goto PAUSE_BACK

rem ======================================================================
rem  [7] BIOS / UEFI ga qayta yoqish
rem ======================================================================
:T_BIOS
call "!TK_C!" :NEED_ADMIN bios || goto BACK
call "!TK_C!" :HEADER "!T_M7!"
call "!TK_C!" :WARN "!T_BIOS_WARN!"
call "!TK_C!" :ASK_YN "!T_ASK_BIOS!"
if errorlevel 1 goto BACK
shutdown /r /fw /t 10
if errorlevel 1 goto CMD_FAIL
call "!TK_C!" :LOG ACTION "reboot to firmware scheduled (10 s)"
call "!TK_C!" :COUNTDOWN 10
if errorlevel 1 goto PAUSE_BACK
exit /b 0

rem ======================================================================
rem  [8] Kompyuterni o'chirish (30 soniya, bekor qilish mumkin)
rem ======================================================================
:T_OFF
call "!TK_C!" :HEADER "!T_M8!"
call "!TK_C!" :WARN "!T_OFF_WARN!"
call "!TK_C!" :ASK_YN "!T_ASK_OFF!"
if errorlevel 1 goto BACK
shutdown /s /t 30
if errorlevel 1 goto CMD_FAIL
call "!TK_C!" :LOG ACTION "shutdown scheduled (30 s)"
call "!TK_C!" :COUNTDOWN 30
if errorlevel 1 goto PAUSE_BACK
exit /b 0

:CMD_FAIL
echo.
call "!TK_C!" :ERR "!T_FAIL!"
goto PAUSE_BACK

rem ======================================================================
rem  [9] Winget: avval ro'yxat, keyin tasdiq (v1.0 da tasdiqsiz edi)
rem ======================================================================
:T_WG
call "!TK_C!" :HEADER "!T_M9!"
where winget >nul 2>&1
if errorlevel 1 goto WG_MISSING
call "!TK_C!" :INFO "!T_WG_LIST!"
echo.
winget upgrade --accept-source-agreements
echo.
call "!TK_C!" :ASK_YN "!T_WG_ASK!"
if errorlevel 1 goto BACK
echo.
call "!TK_C!" :LOG ACTION "winget upgrade --all start"
winget upgrade --all --accept-source-agreements --accept-package-agreements
set "RC=!errorlevel!"
call "!TK_C!" :LOG INFO "winget upgrade --all rc=!RC!"
echo.
if "!RC!"=="0" goto WG_OK
call "!TK_C!" :WARN "!T_WG_WARN! [code !RC!]"
goto PAUSE_BACK

:WG_OK
call "!TK_C!" :OK "!T_WG_OK!"
goto PAUSE_BACK

:WG_MISSING
call "!TK_C!" :ERR "!T_WG_MISSING!"
goto PAUSE_BACK

rem ======================================================================
rem  [10] Port va Lokal Servis menejeri  (modules\ports.bat + ports.ps1)
rem ======================================================================
:T_PORT
call "!TK_ROOT!\modules\ports.bat"
set "RC=!errorlevel!"
set "TK_MOD=main"
if "!RC!"=="0" goto BACK
if "!RC!"=="20" goto PORT_ELEVATE
goto PAUSE_BACK

:PORT_ELEVATE
call "!TK_C!" :RELAUNCH ports
goto PAUSE_BACK

rem ======================================================================
rem  [11] .env tekshiruvchi  (modules\env.bat + env.ps1)
rem  Chiqish kodi: 0 = toza, 1 = muammo bor, 2 = kirish xatosi
rem  CLI (oneshot) rejimda shu kod bilan chiqiladi.
rem ======================================================================
:T_CHLOG
call "!TK_ROOT!\modules\changelog.bat"
set "RC=!errorlevel!"
set "TK_MOD=main"
if defined TK_ONESHOT (
    call "!TK_C!" :LOG INFO "exit rc=!RC!"
    popd
    exit /b !RC!
)
if "!RC!"=="0" goto BACK
goto PAUSE_BACK

:T_DOTENV
call "!TK_ROOT!\modules\env.bat"
set "RC=!errorlevel!"
set "TK_MOD=main"
if defined TK_ONESHOT (
    call "!TK_C!" :LOG INFO "exit rc=!RC!"
    popd
    exit /b !RC!
)
if "!RC!"=="0" goto BACK
if "!RC!"=="1" goto BACK
goto PAUSE_BACK

rem ======================================================================
rem  Til tanlash
rem ======================================================================
:T_LANG
call "!TK_C!" :HEADER "SELECT LANGUAGE / TILNI TANLANG"
echo     %C_C%[1]%C_0%   O'zbekcha
echo     %C_C%[2]%C_0%   English
echo.
choice /c 12 /n /m "  >> "
if errorlevel 2 (set "TK_LANG=EN") else (set "TK_LANG=UZ")
echo !TK_LANG!>"!TK_CFG!" 2>nul
call :LANG_!TK_LANG!
call "!TK_C!" :LANG_!TK_LANG!
call "!TK_C!" :LOG INFO "language=!TK_LANG!"
goto BACK

rem ======================================================================
rem  About
rem ======================================================================
:T_ABOUT
call "!TK_C!" :HEADER "ABOUT TOOLKIT"
echo     Vohid TOOLKIT v!TK_VER!
echo     ----------------------------------------------------------------
echo     !T_AB1!
echo     !T_AB2!
echo     !T_AB3!
echo     !T_AB4!
echo.
echo     !T_AB_AUTHOR!
echo     Gmail   : mnmbackend@gmail.com
echo     GitHub  : github.com/mnmbackend
echo     Log     : !TK_LOGFILE!
goto PAUSE_BACK

rem ======================================================================
rem  Oqim boshqaruvi
rem ======================================================================
:PAUSE_BACK
echo.
echo   %C_D%!T_PRESS!%C_0%
pause >nul
goto BACK

:BACK
set "TK_MOD=main"
if defined TK_ONESHOT goto QUIT
goto MENU

:QUIT
call "!TK_C!" :LOG INFO "exit"
popd
exit /b 0

rem ======================================================================
rem  Tillar (umumiy matnlar: lib\core.bat; modul matnlari: modules\*.bat)
rem ======================================================================
:LANG_UZ
set "T_SUB=Windows tizim yordamchisi"
set "T_G1=ASBOBLAR"
set "T_G2=TIZIM"
set "T_G3=DASTURLAR, TARMOQ VA DEVOPS"
set "T_M1=Terminal (CMD)"
set "T_M2=PowerShell"
set "T_M3=Environment Variables (PATH)"
set "T_M4=Device Manager (Qurilmalar dispetcheri)"
set "T_M5=Tizimni skanerlash va tuzatish (DISM + SFC)"
set "T_M6=Windows aktivatsiya holati"
set "T_M7=BIOS (UEFI) sozlamalariga qayta yoqish"
set "T_M8=Kompyuterni o'chirish - 30 soniyadan keyin"
set "T_M9=Barcha dasturlarni yangilash (Winget)"
set "T_M10=Portlar va lokal servislar"
set "T_M11=.env tekshiruvchi (.env.example bilan solishtirish)"
set "T_M12=Git changelog / release notes"
set "T_MA=Haqida"
set "T_ML=Til"
set "T_M0=Chiqish"
set "T_ADMIN_NOTE=Administrator huquqi kerak (kerak bo'lganda so'raladi)."
set "T_INVALID=Noto'g'ri buyruq. Qayta urinib ko'ring."
set "T_UNKNOWN=Noma'lum buyruq:"
set "T_USAGE=Buyruqlar: cmd ps path devmgr scan activation bios shutdown winget ports env changelog about   Parametr: --lang UZ/EN  --no-color  --ci"
set "T_SCAN1=DISM: tizim obrazini tiklash..."
set "T_SCAN2=SFC: Windows fayllarini tekshirish..."
set "T_SCAN_DONE=Skanerlash va tiklash yakunlandi."
set "T_SCAN_WARN=Skanerlash xato yoki ogohlantirish bilan yakunlandi. Natijani tekshiring."
set "T_LOG=Batafsil log:"
set "T_ACT_NOTE=Aktivatsiya Sozlamalar sahifasida yoki o'z litsenziya kalitingiz orqali amalga oshiriladi."
set "T_ACT_OPEN=Aktivatsiya sozlamalari ochilsinmi?"
set "T_BIOS_WARN=Saqlanmagan ishlar yo'qoladi. Kompyuter UEFI sozlamalariga qayta yoqiladi."
set "T_ASK_BIOS=BIOS ga qayta yoqishni tasdiqlaysizmi?"
set "T_OFF_WARN=Saqlanmagan ishlar yo'qoladi."
set "T_ASK_OFF=Kompyuter 30 soniyadan so'ng o'chirilsinmi?"
set "T_FAIL=Bajarib bo'lmadi. UEFI qo'llab-quvvatlanmasligi yoki boshqa o'chirish jarayoni kutilayotgan bo'lishi mumkin."
set "T_WG_MISSING=Winget topilmadi. Microsoft Store orqali App Installer ni o'rnating."
set "T_WG_LIST=Mavjud yangilanishlar:"
set "T_WG_ASK=Yuqoridagi barcha dasturlar yangilansinmi?"
set "T_WG_OK=Barcha dasturlar yangilandi."
set "T_WG_WARN=Winget ogohlantirish bilan yakunlandi. Yuqoridagi natijani tekshiring."
set "T_AB1=Windows tizimini boshqarish va DevOps vazifalarini avtomatlashtirish"
set "T_AB2=uchun mo'ljallangan tezkor CLI yordamchi. Tizim fayllarini skan"
set "T_AB3=qilish, band portlarni xavfsiz yopish, PATH sozlamalariga kirish va"
set "T_AB4=dasturlarni avto-yangilash kabi amallarni tezkor bajaradi."
set "T_AB_AUTHOR=Muallif : Muhammadamin Vohid"
exit /b 0

:LANG_EN
set "T_SUB=Windows system helper"
set "T_G1=TOOLS"
set "T_G2=SYSTEM"
set "T_G3=SOFTWARE, NETWORK AND DEVOPS"
set "T_M1=Terminal (CMD)"
set "T_M2=PowerShell"
set "T_M3=Environment Variables (PATH)"
set "T_M4=Device Manager"
set "T_M5=System scan and repair (DISM + SFC)"
set "T_M6=Windows activation status"
set "T_M7=Reboot to BIOS (UEFI)"
set "T_M8=Shutdown computer - in 30 seconds"
set "T_M9=Update all software (Winget)"
set "T_M10=Ports and local services"
set "T_M11=.env checker (compare with .env.example)"
set "T_M12=Git changelog / release notes"
set "T_MA=About"
set "T_ML=Language"
set "T_M0=Exit"
set "T_ADMIN_NOTE=Requires administrator rights (asked when needed)."
set "T_INVALID=Invalid command. Please try again."
set "T_UNKNOWN=Unknown command:"
set "T_USAGE=Commands: cmd ps path devmgr scan activation bios shutdown winget ports env changelog about   Options: --lang UZ/EN  --no-color  --ci"
set "T_SCAN1=DISM: repairing system image..."
set "T_SCAN2=SFC: scanning Windows system files..."
set "T_SCAN_DONE=Scan and repair completed."
set "T_SCAN_WARN=Scan finished with errors or warnings. Check the output."
set "T_LOG=Detailed log:"
set "T_ACT_NOTE=Activate through the Settings page or with your own license key."
set "T_ACT_OPEN=Open activation settings?"
set "T_BIOS_WARN=Unsaved work will be lost. The computer will reboot into UEFI setup."
set "T_ASK_BIOS=Confirm reboot to BIOS?"
set "T_OFF_WARN=Unsaved work will be lost."
set "T_ASK_OFF=Shut down the computer in 30 seconds?"
set "T_FAIL=Failed. UEFI may be unsupported or another shutdown is already pending."
set "T_WG_MISSING=Winget not found. Install App Installer from the Microsoft Store."
set "T_WG_LIST=Available updates:"
set "T_WG_ASK=Update all the software listed above?"
set "T_WG_OK=All applications updated."
set "T_WG_WARN=Winget finished with warnings. Check the output above."
set "T_AB1=A lightweight, highly automated CLI toolkit designed for Windows"
set "T_AB2=system administration and DevOps operations. It streamlines core"
set "T_AB3=tasks like safe network port management, system repairs, environment"
set "T_AB4=variables configuration, and software updates."
set "T_AB_AUTHOR=Author  : Muhammadamin Vohid"
exit /b 0
