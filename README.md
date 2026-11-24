# V-Toolkit (Vohid TOOLKIT)

**English** | [O'zbekcha](README.uz.md)

Windows SysAdmin + Backend/DevOps CLI. UZ / EN interface. License: MIT.

## Requirements

Windows 10/11, PowerShell 5.1+. Administrator rights are requested only when an action needs them.

## Usage

Run `TOOLKIT.bat`, or use the CLI form:

```
TOOLKIT.bat [command] [--lang UZ|EN] [--no-color]
commands: cmd ps path devmgr scan activation bios shutdown winget ports env about
```

## Ports and local services (`ports`)

```
  PORT    NAME              STATE    PID      PROCESS            BIND
  ----------------------------------------------------------------------
  3000    Node / React      FREE     -        -                  -
  5173    Vite              LISTEN   14320    node               127.0.0.1,::1
  5432    PostgreSQL        LISTEN   5120     postgres           127.0.0.1
  6379    Redis             LISTEN   8844     redis-server       0.0.0.0 !
  8000    Django / FastAPI  FREE     -        -                  -
  8080    HTTP (alt)        LISTEN   9912     com.docker.backend 0.0.0.0
```
*(sample)*

- Default ports: 3000, 5173, 5432, 6379, 8000, 8080. Extra ports: `%LOCALAPPDATA%\VohidToolkit\ports.txt` (`PORT=Name`).
- The port is validated to `1-65535`.
- Critical system processes (`lsass`, `csrss`, `svchost`, `System`, ...) and the toolkit itself are never stopped.
- If a Windows service owns the port, the service is stopped, not the process.
- Docker, WSL, browsers and IDEs require typing the port number to confirm.
- PID and start time are re-verified right before stopping.

## `.env` checker (`env`)

```
TOOLKIT.bat env [folder] [--ci]
```

```
  MISSING   2   in the example, not in .env
      DATABASE_URL
      JWT_SECRET

  EMPTY     1   example has a value, .env is empty
      PORT

  EXTRA     1   not in the example (extra, warning only)
      LEGACY_FLAG
```
*(sample)*

- Compares `.env` with `.env.example` (or `.sample` / `.template`): `MISSING`, `EMPTY`, `EXTRA`, `DUPLICATE`.
- `EMPTY` is reported only when the example has a value. An empty key in the example (`KEY=`) is treated as optional.
- `EXTRA` is a warning only and does not fail CI.
- **Values are never displayed or logged.**
- Missing keys can be appended with empty values (backup to `.env.bak` + confirmation). Add `*.bak` to `.gitignore`.
- `--ci` is non-interactive and colorless. Exit code: `0` clean, `1` problems found, `2` input error.

## Logs

`%LOCALAPPDATA%\VohidToolkit\logs\toolkit-YYYY-MM-DD.log` (14-day retention; command lines and values are never logged).

## Layout

`TOOLKIT.bat` (menu) | `lib\` (shared helpers) | `modules\*.bat` (UI + `LANG_UZ` / `LANG_EN`) + `modules\*.ps1` (logic).

Note: `.bat` files must keep CRLF line endings (enforced by `.gitattributes`). Do not use `! % "` in UI strings.

## Roadmap

| Version | Content |
|---|---|
| v2.0 | Modular core, lazy admin, ports manager |
| v2.1 | `.env` checker |
| v2.2 | Git changelog / release notes (Conventional Commits) |
| v2.3 | Safe system cleaner (dry-run first) |

> Keep `README.md` and `README.uz.md` in sync: update both in the same commit.
