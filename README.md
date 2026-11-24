# V-Toolkit (Vohid TOOLKIT v2.0)

Windows SysAdmin + Backend/DevOps CLI. UZ / EN.

## O'zbekcha

**Talab:** Windows 10/11, PowerShell 5.1+. Administrator huquqi faqat kerak bo'lganda so'raladi.

**Ishga tushirish:** `TOOLKIT.bat` ni oching yoki buyruq bilan:

```
TOOLKIT.bat [buyruq] [--lang UZ|EN] [--no-color]
buyruqlar: cmd ps path devmgr scan activation bios shutdown winget ports about
```

**Portlar va lokal servislar (`ports`):**
- 3000, 5173, 5432, 6379, 8000, 8080 holati, PID, jarayon nomi, bind manzili. Qo'shimcha portlar: `%LOCALAPPDATA%\VohidToolkit\ports.txt` (`PORT=Nom`).
- Port `1-65535` oralig'ida tekshiriladi.
- Tizim jarayonlari (`lsass`, `csrss`, `svchost`, `System` va h.k.) hamda Toolkit o'zi to'xtatilmaydi.
- Windows servisi bo'lsa, jarayon emas, servis to'xtatiladi.
- Docker/WSL/brauzer/IDE uchun port raqamini yozib tasdiqlash kerak.
- O'chirishdan oldin PID va boshlanish vaqti qayta tekshiriladi.

**Log:** `%LOCALAPPDATA%\VohidToolkit\logs\toolkit-YYYY-MM-DD.log` (14 kun saqlanadi; buyruq qatorlari va qiymatlar yozilmaydi).

**Tuzilma:** `TOOLKIT.bat` (menyu) | `lib\` (umumiy yordamchilar) | `modules\*.bat` (UI + LANG_UZ/LANG_EN) + `modules\*.ps1` (mantiq).

**Muhim:** `.bat` fayllar CRLF bilan saqlanishi shart (`.gitattributes` buni ta'minlaydi). Matnlarda `! % "` ishlatmang.

**Reja:** `.env` tekshiruvchi, Git changelog, tizim tozalash.

## English

**Requirements:** Windows 10/11, PowerShell 5.1+. Administrator rights are requested only when an action needs them.

**Usage:** run `TOOLKIT.bat`, or use the CLI form shown above.

**Ports and local services (`ports`):** dashboard for common dev ports with PID, process name and bind address; port validated to `1-65535`; critical system processes and the toolkit itself are never stopped; Windows services are stopped as services; Docker/WSL/browsers/IDEs require typing the port number to confirm; the target is re-verified (PID and start time) right before stopping. Extra ports: `%LOCALAPPDATA%\VohidToolkit\ports.txt` (`PORT=Name`).

**Logs:** `%LOCALAPPDATA%\VohidToolkit\logs\toolkit-YYYY-MM-DD.log` (14-day retention; no command lines or values are logged).

**Layout:** `TOOLKIT.bat` (menu) | `lib\` (shared helpers) | `modules\*.bat` (UI + LANG_UZ/LANG_EN) + `modules\*.ps1` (logic).

**Roadmap:** `.env` checker, Git changelog, safe system cleaner.
