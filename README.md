# V-Toolkit (Vohid TOOLKIT)

Windows SysAdmin + Backend/DevOps CLI. UZ / EN. License: MIT.

## O'zbekcha

**Talab:** Windows 10/11, PowerShell 5.1+. Administrator huquqi faqat kerak bo'lganda so'raladi.

**Ishga tushirish:** `TOOLKIT.bat` ni oching yoki buyruq bilan:

```
TOOLKIT.bat [buyruq] [--lang UZ|EN] [--no-color]
buyruqlar: cmd ps path devmgr scan activation bios shutdown winget ports env about
```

### Portlar va lokal servislar (`ports`)

```
  PORT    NOMI              HOLAT    PID      JARAYON            MANZIL
  ----------------------------------------------------------------------
  3000    Node / React      BO'SH    -        -                  -
  5173    Vite              BAND     14320    node               127.0.0.1,::1
  5432    PostgreSQL        BAND     5120     postgres           127.0.0.1
  6379    Redis             BAND     8844     redis-server       0.0.0.0 !
  8000    Django / FastAPI  BO'SH    -        -                  -
  8080    HTTP (alt)        BAND     9912     com.docker.backend 0.0.0.0
```
*(namuna)*

- Standart portlar: 3000, 5173, 5432, 6379, 8000, 8080. Qo'shimcha: `%LOCALAPPDATA%\VohidToolkit\ports.txt` (`PORT=Nom`).
- Port `1-65535` oralig'ida tekshiriladi.
- Tizim jarayonlari (`lsass`, `csrss`, `svchost`, `System` va h.k.) hamda Toolkit o'zi to'xtatilmaydi.
- Windows servisi bo'lsa, jarayon emas, servis to'xtatiladi.
- Docker/WSL/brauzer/IDE uchun port raqamini yozib tasdiqlash kerak.
- O'chirishdan oldin PID va boshlanish vaqti qayta tekshiriladi.

### `.env` tekshiruvchi (`env`)

```
TOOLKIT.bat env [papka] [--ci]
```

```
  MISSING   2   namunada bor, .env da yo'q
      DATABASE_URL
      JWT_SECRET

  EMPTY     1   namunada qiymat bor, .env da bo'sh
      PORT

  EXTRA     1   namunada yo'q (ortiqcha, ogohlantirish)
      LEGACY_FLAG
```
*(namuna)*

- `.env.example` (yoki `.sample` / `.template`) bilan `.env` solishtiriladi: `MISSING`, `EMPTY`, `EXTRA`, `DUPLICATE`.
- `EMPTY`: faqat namunada qiymat bor bo'lsa. Namunada bo'sh (`KEY=`) kalit ixtiyoriy hisoblanadi.
- `EXTRA` faqat ogohlantirish; CI'ni yiqitmaydi.
- **Qiymatlar hech qachon ekranga va logga chiqmaydi.**
- Yetishmayotgan kalitlarni bo'sh qiymat bilan qo'shish mumkin (`.env.bak` zaxirasi va tasdiq bilan). `*.bak` ni `.gitignore` ga qo'shing.
- `--ci`: savolsiz, rangsiz; chiqish kodi `0` toza, `1` muammo bor, `2` kirish xatosi.

**Log:** `%LOCALAPPDATA%\VohidToolkit\logs\toolkit-YYYY-MM-DD.log` (14 kun; buyruq qatorlari va qiymatlar yozilmaydi).

**Tuzilma:** `TOOLKIT.bat` (menyu) | `lib\` (umumiy yordamchilar) | `modules\*.bat` (UI + LANG_UZ/LANG_EN) + `modules\*.ps1` (mantiq).

**Muhim:** `.bat` fayllar CRLF bilan saqlanishi shart (`.gitattributes` buni ta'minlaydi). Matnlarda `! % "` ishlatmang.

## English

**Requirements:** Windows 10/11, PowerShell 5.1+. Administrator rights are requested only when an action needs them.

**Usage:** run `TOOLKIT.bat`, or use the CLI form shown above.

**Ports and local services (`ports`):** dashboard for common dev ports with PID, process name and bind address; port validated to `1-65535`; critical system processes and the toolkit itself are never stopped; Windows services are stopped as services; Docker/WSL/browsers/IDEs require typing the port number to confirm; the target is re-verified (PID and start time) right before stopping. Extra ports: `%LOCALAPPDATA%\VohidToolkit\ports.txt` (`PORT=Name`).

**`.env` checker (`env`):** compares `.env` with `.env.example` and reports `MISSING`, `EMPTY` (only when the example has a value), `EXTRA` (warning only) and `DUPLICATE`. Values are never displayed or logged. Can append missing keys with empty values (backup + confirmation). `--ci` is non-interactive and returns exit code `0` (clean), `1` (problems), `2` (input error).

**Logs:** `%LOCALAPPDATA%\VohidToolkit\logs\toolkit-YYYY-MM-DD.log` (14-day retention; no command lines or values are logged).

**Layout:** `TOOLKIT.bat` (menu) | `lib\` (shared helpers) | `modules\*.bat` (UI + LANG_UZ/LANG_EN) + `modules\*.ps1` (logic).

## Roadmap

| Version | Content |
|---|---|
| v2.0 | Modular core, lazy admin, ports manager |
| v2.1 | `.env` checker |
| v2.2 | Git changelog / release notes (Conventional Commits) |
| v2.3 | Safe system cleaner (dry-run first) |
