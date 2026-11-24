@echo off
rem ======================================================================
rem  modules\env.bat  -  .env tekshiruvchi (UI qobig'i)
rem  Matnlar: LANG_UZ / LANG_EN (T_E_*). Mantiq: modules\env.ps1
rem  Kirish (muhit): TK_ARG = papka (ixtiyoriy), TK_CI = 1 (ixtiyoriy), TK_CWD
rem  Chiqish kodi: 0 = toza, 1 = muammo bor, 2 = kirish xatosi
rem ======================================================================
setlocal EnableExtensions EnableDelayedExpansion
set "TK_MOD=env"
call :LANG_!TK_LANG!

powershell -NoProfile -ExecutionPolicy Bypass -File "!TK_ROOT!\modules\env.ps1"
set "RC=!errorlevel!"

if "!RC!"=="0" endlocal & exit /b 0
if "!RC!"=="1" endlocal & exit /b 1
if "!RC!"=="2" endlocal & exit /b 2

echo.
call "!TK_C!" :ERR "!T_E_PSFAIL! [code !RC!]"
endlocal & exit /b %RC%

rem ======================================================================
rem  Tillar
rem ======================================================================
:LANG_UZ
set "T_E_TITLE=.ENV TEKSHIRUVCHI"
set "T_E_PROMPT_DIR=Loyiha papkasi (Enter = {0}, 0 = orqaga):"
set "T_E_NODIR=Papka topilmadi:"
set "T_E_NOEX=Namuna fayl topilmadi (.env.example, .env.sample yoki .env.template)."
set "T_E_NOTARGET={0} fayli yo'q: namunadagi barcha kalitlar yetishmayotgan hisoblanadi."
set "T_E_PICK=Bir nechta .env fayl topildi. Raqamini tanlang (Enter = 1):"
set "T_E_COMPARE=Namuna: {0}    Tekshiriladi: {1}"
set "T_E_D_MISSING=namunada bor, .env da yo'q"
set "T_E_D_EMPTY=namunada qiymat bor, .env da bo'sh"
set "T_E_D_EXTRA=namunada yo'q (ortiqcha, ogohlantirish)"
set "T_E_D_DUPLICATE=bir necha marta e'lon qilingan"
set "T_E_MORE=... va yana {0} ta"
set "T_E_INVALID=Noto'g'ri formatdagi qator raqamlari (mazmuni ko'rsatilmaydi): {0}"
set "T_E_SUMMARY=Namuna kalitlari: {0}   MISSING {1}   EMPTY {2}   EXTRA {3}   DUPLICATE {4}"
set "T_E_NOVALUES=Qiymatlar hech qachon ko'rsatilmaydi va logga yozilmaydi."
set "T_E_CLEAN=Hammasi joyida: .env namunaga mos."
set "T_E_PROBLEMS=Muammolar topildi."
set "T_E_ASK_FIX={0} ta yetishmayotgan kalit {1} ga bo'sh qiymat bilan qo'shilsinmi?"
set "T_E_ASK_CREATE={1} fayli yaratilib, {0} ta kalit bo'sh qiymat bilan yozilsinmi?"
set "T_E_FIXED=Qo'shildi (kalit soni):"
set "T_E_BACKUP=Zaxira nusxa:"
set "T_E_BAK_NOTE=Zaxirada maxfiy qiymatlar bor. *.bak ni .gitignore ga qo'shing."
set "T_E_FIX_FAIL=Faylga yozib bo'lmadi:"
set "T_E_HINT=[R] Qayta tekshirish     [D] Boshqa papka     [0] Orqaga"
set "T_E_FAIL=Modul xatosi:"
set "T_E_PSFAIL=PowerShell modulini ishga tushirib bo'lmadi. Execution Policy yoki antivirusni tekshiring."
exit /b 0

:LANG_EN
set "T_E_TITLE=.ENV CHECKER"
set "T_E_PROMPT_DIR=Project folder (Enter = {0}, 0 = back):"
set "T_E_NODIR=Folder not found:"
set "T_E_NOEX=Example file not found (.env.example, .env.sample or .env.template)."
set "T_E_NOTARGET={0} does not exist: every key in the example counts as missing."
set "T_E_PICK=Several .env files found. Pick a number (Enter = 1):"
set "T_E_COMPARE=Example: {0}    Checking: {1}"
set "T_E_D_MISSING=in the example, not in .env"
set "T_E_D_EMPTY=example has a value, .env is empty"
set "T_E_D_EXTRA=not in the example (extra, warning only)"
set "T_E_D_DUPLICATE=declared more than once"
set "T_E_MORE=... and {0} more"
set "T_E_INVALID=Malformed line numbers (content is not shown): {0}"
set "T_E_SUMMARY=Example keys: {0}   MISSING {1}   EMPTY {2}   EXTRA {3}   DUPLICATE {4}"
set "T_E_NOVALUES=Values are never displayed and never written to the log."
set "T_E_CLEAN=All good: .env matches the example."
set "T_E_PROBLEMS=Problems found."
set "T_E_ASK_FIX=Add {0} missing key(s) to {1} with empty values?"
set "T_E_ASK_CREATE=Create {1} and write {0} key(s) with empty values?"
set "T_E_FIXED=Added (key count):"
set "T_E_BACKUP=Backup copy:"
set "T_E_BAK_NOTE=The backup contains secrets. Add *.bak to .gitignore."
set "T_E_FIX_FAIL=Could not write the file:"
set "T_E_HINT=[R] Recheck     [D] Another folder     [0] Back"
set "T_E_FAIL=Module error:"
set "T_E_PSFAIL=Could not start the PowerShell module. Check Execution Policy or antivirus."
exit /b 0
