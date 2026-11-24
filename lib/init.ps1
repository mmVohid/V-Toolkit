# lib\init.ps1 - ishga tushirishda bir marta: log papkasi, eski loglarni tozalash, bugungi sana.
# Chiqish: stdout ga faqat YYYY-MM-DD (TOOLKIT.bat TK_DATE ga o'qiydi).
$ErrorActionPreference = 'SilentlyContinue'

$dir = Join-Path $env:LOCALAPPDATA 'VohidToolkit\logs'
New-Item -ItemType Directory -Force -Path $dir | Out-Null

$limit = (Get-Date).AddDays(-14)
Get-ChildItem -LiteralPath $dir -Filter 'toolkit-*.log' |
    Where-Object { $_.LastWriteTime -lt $limit } |
    Remove-Item -Force

Get-Date -Format 'yyyy-MM-dd'
