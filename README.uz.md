# V-Toolkit (Vohid TOOLKIT)

[English](README.md) | **O'zbekcha**

Windows SysAdmin + Backend/DevOps CLI. UZ / EN interfeys. Litsenziya: MIT.

## Talablar

Windows 10/11, PowerShell 5.1+. Administrator huquqi faqat kerak bo'lganda so'raladi.

## Ishga tushirish

`TOOLKIT.bat` ni oching yoki buyruq bilan:

```
TOOLKIT.bat [buyruq] [--lang UZ|EN] [--no-color]
buyruqlar: cmd ps path devmgr scan activation bios shutdown winget ports env about
```

## Portlar va lokal servislar (`ports`)

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
- Docker, WSL, brauzer va IDE uchun port raqamini yozib tasdiqlash kerak.
- To'xtatishdan oldin PID va boshlanish vaqti qayta tekshiriladi.

## `.env` tekshiruvchi (`env`)

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

- `.env` ni `.env.example` (yoki `.sample` / `.template`) bilan solishtiradi: `MISSING`, `EMPTY`, `EXTRA`, `DUPLICATE`.
- `EMPTY` faqat namunada qiymat bor bo'lsa chiqadi. Namunada bo'sh (`KEY=`) kalit ixtiyoriy hisoblanadi.
- `EXTRA` faqat ogohlantirish; CI'ni yiqitmaydi.
- **Qiymatlar hech qachon ekranga va logga chiqmaydi.**
- Yetishmayotgan kalitlarni bo'sh qiymat bilan qo'shish mumkin (`.env.bak` zaxirasi va tasdiq bilan). `*.bak` ni `.gitignore` ga qo'shing.
- `--ci` savolsiz va rangsiz ishlaydi. Chiqish kodi: `0` toza, `1` muammo bor, `2` kirish xatosi.

## Git changelog (`changelog`)

```
TOOLKIT.bat changelog [papka] [--ci]
```

```
## Unreleased - 2026-11-24

### Features

- **ports:** watched-ports dashboard (`a1b2c3d`)

### Fixes

- avoid timeout.exe with redirected stdin (`d4e5f6a`)
```

- Oraliq: oxirgi tegdan `HEAD` gacha (teg bo'lmasa - butun tarix). `HEAD` aynan tegda tursa, oldingi tegdan shu teggacha.
- [Conventional Commits](https://www.conventionalcommits.org/) bo'yicha guruhlaydi (`feat`, `fix`, `perf`, `refactor`, `docs`, `test`, `ci`, `build`, `style`, `chore`; `!` = buzuvchi o'zgarish). Qolganlari **Boshqalar** ga tushadi.
- Interaktiv rejim: avval ko'rsatadi, `RELEASE_NOTES.md` yaratishdan oldin so'raydi; fayl bor bo'lsa, yangi blok boshiga qo'shiladi, eski mazmun saqlanadi.
- `--ci` toza Markdown ni stdout ga chiqaradi, fayl yozmaydi. Chiqish kodi: `0` ok, `2` kirish xatosi (git yo'q / repozitoriy emas).
- Faqat commit sarlavhalari o'qiladi.

## Log

`%LOCALAPPDATA%\VohidToolkit\logs\toolkit-YYYY-MM-DD.log` (14 kun saqlanadi; buyruq qatorlari va qiymatlar yozilmaydi).

## Tuzilma

`TOOLKIT.bat` (menyu) | `lib\` (umumiy yordamchilar) | `modules\*.bat` (UI + `LANG_UZ` / `LANG_EN`) + `modules\*.ps1` (mantiq).

Eslatma: `.bat` fayllar CRLF qator oxiri bilan saqlanishi shart (`.gitattributes` ta'minlaydi). UI matnlarida `! % "` ishlatmang.

## Roadmap

| Versiya | Tarkib |
|---|---|
| v2.0 | Modulli poydevor, lazy admin, port menejeri |
| v2.1 | `.env` tekshiruvchi |
| v2.2 | Git changelog / release notes (Conventional Commits) - jarayonda |
| v2.3 | Xavfsiz tizim tozalash (avval dry-run) |

> `README.md` va `README.uz.md` ni sinxron saqlang: ikkalasini bitta commitda yangilang.
