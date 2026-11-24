# Qo'lda test ro'yxati (CI qamrab olmaydigan qismlar)

CI (`windows-latest`) administrator sifatida ishlaydi va interaktiv UAC yo'q. Quyidagilarni o'z Windows'ingizda tekshiring.

## 1. Administrator va UAC (oddiy, elevated bo'lmagan oynada)
- [ ] Menyuda `Admin: OFF` va `*` belgilari ([5], [7]) ko'rinadi.
- [ ] [5] ni bosing: "Administrator huquqi kerak" -> Y -> UAC -> yangi oynada DISM/SFC ishlaydi.
- [ ] UAC'da "No": xato xabari, asosiy oyna ishlashda davom etadi.
- [ ] `TOOLKIT.bat scan` oddiy oynada ham shu oqimni beradi.
- [ ] Yo'lida `'` yoki `!` bor papkadan (`C:\Test O'tkir!\`) ishga tushganda menyu ochiladi, relaunch ishlaydi.

## 2. Ko'rinish
- [ ] Classic CMD, Windows Terminal, PowerShell 5.1 ichidan: ranglar to'g'ri, `←[` kabi belgilar yo'q.
- [ ] `--no-color` va `set NO_COLOR=1`: rangsiz, o'qiladi.
- [ ] Menyu kengligi 84 ustunga sig'adi; dashboard jadvali qatlamaydi.

## 3. Portlar (haqiqiy tizimda)
- [ ] `python -m http.server 8000` -> `[10]` -> `8000`: ma'lumot, `Y` -> to'xtaydi, port BO'SH.
- [ ] `135`, `445`, `4`: rad etiladi (HIMOYALANGAN).
- [ ] Docker Desktop ishlayotganda `8080`/`5432` (agar Docker ochgan bo'lsa): WARN, port raqamini yozish talab qilinadi; noto'g'ri yozsangiz bekor.
- [ ] Windows servisi tinglayotgan port (masalan PostgreSQL servisi, 5432): "SERVIS", oddiy oynada admin so'raydi, adminda `Stop-Service` ishlaydi.
- [ ] Brauzer oynasi ochiq (CloseMainWindow yo'li): 4 soniyadan keyin majburiy tugatish so'raladi.
- [ ] `%LOCALAPPDATA%\VohidToolkit\ports.txt` ga `7000=Test` yozing: jadvalda paydo bo'ladi.
- [ ] DB porti `0.0.0.0` da ochiq bo'lsa `!` belgisi va ogohlantirish chiqadi.

## 4. `.env`
- [ ] Real loyihada: `env <papka>` natijasi to'g'ri; qiymatlar hech qayerda ko'rinmaydi.
- [ ] Interaktiv: "yetishmayotganlarni qo'shish" -> `.env.bak` yaratiladi -> qayta tekshiruv toza.
- [ ] Bir nechta `.env*` fayl bor papkada tanlov menyusi.
- [ ] Oxirgi papka keyingi safar eslab qolinadi.

## 5. Xavfli amallar (bekor qilish yo'lini tekshiring)
- [ ] [8] Shutdown: 30 soniya ichida `C` bosilsa bekor qilinadi (`shutdown /a`).
- [ ] [7] BIOS: tasdiqdan keyin 10 soniyalik hisoblagich, `C` bilan bekor.
- [ ] [9] Winget: ro'yxat -> `N` -> hech narsa o'rnatilmaydi.

## 6. Til va log
- [ ] `L` -> English -> qayta ishga tushirganda til saqlanadi; `--lang UZ` ustun keladi.
- [ ] `%LOCALAPPDATA%\VohidToolkit\logs\` da bugungi fayl; 14 kundan eskilari o'chadi.
