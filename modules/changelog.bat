@echo off
rem ======================================================================
rem  modules\changelog.bat  -  Git changelog / release notes (UI qobig'i)
rem  Matnlar: LANG_UZ / LANG_EN (T_C_*). Mantiq: modules\changelog.ps1
rem  Kirish (muhit): TK_ARG = papka (ixtiyoriy), TK_CI = 1 (ixtiyoriy), TK_CWD
rem  Chiqish kodi: 0 = ok, 2 = kirish xatosi
rem ======================================================================
setlocal EnableExtensions EnableDelayedExpansion
set "TK_MOD=changelog"
call :LANG_!TK_LANG!

powershell -NoProfile -ExecutionPolicy Bypass -File "!TK_ROOT!\modules\changelog.ps1"
set "RC=!errorlevel!"

if "!RC!"=="0" endlocal & exit /b 0
if "!RC!"=="2" endlocal & exit /b 2

echo.
call "!TK_C!" :ERR "!T_C_PSFAIL! [code !RC!]"
endlocal & exit /b %RC%

rem ======================================================================
rem  Tillar
rem ======================================================================
:LANG_UZ
set "T_C_TITLE=GIT CHANGELOG / RELEASE NOTES"
set "T_C_PROMPT_DIR=Git papka (Enter = {0}, 0 = orqaga):"
set "T_C_NOGIT=git topilmadi. Git for Windows o'rnating va PATH ga qo'shing."
set "T_C_NOREPO=Bu papka git repozitoriy emas:"
set "T_C_NOCOMMITS=Repozitoriyda hali commit yo'q."
set "T_C_RANGE=Oraliq: {0} .. {1}"
set "T_C_START=boshlanish"
set "T_C_EMPTY=Bu oraliqda yangi commit yo'q."
set "T_C_TOTAL=Commitlar soni: {0}"
set "T_C_UNRELEASED=Chiqarilmagan"
set "T_C_ASK_CREATE={0} fayli yaratilsinmi?"
set "T_C_ASK_PREPEND={0} mavjud. Yangi blok fayl boshiga qo'shilsinmi (eski mazmun saqlanadi)?"
set "T_C_SAVED=Saqlandi:"
set "T_C_WRITE_FAIL=Faylga yozib bo'lmadi:"
set "T_C_HINT=[D] Boshqa papka     [0] Orqaga"
set "T_C_FAIL=Modul xatosi:"
set "T_C_PSFAIL=PowerShell modulini ishga tushirib bo'lmadi. Execution Policy yoki antivirusni tekshiring."
set "T_C_S_BREAKING=Buzuvchi o'zgarishlar"
set "T_C_S_FEAT=Yangiliklar"
set "T_C_S_FIX=Tuzatishlar"
set "T_C_S_PERF=Tezlik"
set "T_C_S_REFACTOR=Qayta yozish"
set "T_C_S_DOCS=Hujjatlar"
set "T_C_S_TEST=Testlar"
set "T_C_S_CI=CI"
set "T_C_S_BUILD=Build"
set "T_C_S_STYLE=Uslub"
set "T_C_S_CHORE=Boshqa ishlar"
set "T_C_S_OTHER=Boshqalar"
exit /b 0

:LANG_EN
set "T_C_TITLE=GIT CHANGELOG / RELEASE NOTES"
set "T_C_PROMPT_DIR=Git folder (Enter = {0}, 0 = back):"
set "T_C_NOGIT=git not found. Install Git for Windows and add it to PATH."
set "T_C_NOREPO=This folder is not a git repository:"
set "T_C_NOCOMMITS=The repository has no commits yet."
set "T_C_RANGE=Range: {0} .. {1}"
set "T_C_START=beginning"
set "T_C_EMPTY=No new commits in this range."
set "T_C_TOTAL=Commits: {0}"
set "T_C_UNRELEASED=Unreleased"
set "T_C_ASK_CREATE=Create {0}?"
set "T_C_ASK_PREPEND={0} exists. Prepend the new block (old content is kept)?"
set "T_C_SAVED=Saved:"
set "T_C_WRITE_FAIL=Could not write the file:"
set "T_C_HINT=[D] Another folder     [0] Back"
set "T_C_FAIL=Module error:"
set "T_C_PSFAIL=Could not start the PowerShell module. Check Execution Policy or antivirus."
set "T_C_S_BREAKING=Breaking changes"
set "T_C_S_FEAT=Features"
set "T_C_S_FIX=Fixes"
set "T_C_S_PERF=Performance"
set "T_C_S_REFACTOR=Refactoring"
set "T_C_S_DOCS=Documentation"
set "T_C_S_TEST=Tests"
set "T_C_S_CI=CI"
set "T_C_S_BUILD=Build"
set "T_C_S_STYLE=Style"
set "T_C_S_CHORE=Chores"
set "T_C_S_OTHER=Other"
exit /b 0
