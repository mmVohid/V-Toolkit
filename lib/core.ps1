# ======================================================================
#  lib\core.ps1 - PowerShell modullari uchun umumiy yordamchilar
#  core.bat ning juftligi: Show-TkHeader / Write-TkOk / Write-TkErr /
#  Write-TkWarn / Write-TkInfo / Confirm-TkYesNo / Write-TkLog
#  Ishlatish:  . (Join-Path $root 'lib\core.ps1')   (dot-source)
#  Matnlar muhit o'zgaruvchilaridan olinadi: T_<NOM> (modul .bat dagi LANG_* bloklari)
# ======================================================================

if ([string]::IsNullOrEmpty($script:TkMod)) { $script:TkMod = 'main' }

# --- VT (ANSI) rejimini yoqish va rang qarori -----------------------------
$script:TkVt = $false
try {
    Add-Type -Namespace TkWin -Name Con -MemberDefinition @'
[DllImport("kernel32.dll")] public static extern System.IntPtr GetStdHandle(int n);
[DllImport("kernel32.dll")] public static extern bool GetConsoleMode(System.IntPtr h, out int m);
[DllImport("kernel32.dll")] public static extern bool SetConsoleMode(System.IntPtr h, int m);
'@ -ErrorAction Stop
    $h = [TkWin.Con]::GetStdHandle(-11)
    [int]$mode = 0
    if ([TkWin.Con]::GetConsoleMode($h, [ref]$mode)) {
        $script:TkVt = [TkWin.Con]::SetConsoleMode($h, ($mode -bor 4))
    }
} catch { }
if (-not $script:TkVt) {
    try { if ($Host.UI.SupportsVirtualTerminal -eq $true) { $script:TkVt = $true } } catch { }
}

$script:TkColor = $script:TkVt
if ($env:NO_COLOR -or $env:TK_NOCOLOR) { $script:TkColor = $false }

$esc = [string][char]27
if ($script:TkColor) {
    $script:Col = @{
        Cyan   = "${esc}[96m"; Green = "${esc}[92m"; Yellow = "${esc}[93m"
        Red    = "${esc}[91m"; Dim   = "${esc}[90m"; White  = "${esc}[97m"
        Reset  = "${esc}[0m"
    }
} else {
    $script:Col = @{ Cyan = ''; Green = ''; Yellow = ''; Red = ''; Dim = ''; White = ''; Reset = '' }
}

# --- Matn va log -------------------------------------------------------------
function Get-TkText([string]$Name) {
    $v = [Environment]::GetEnvironmentVariable('T_' + $Name)
    if ([string]::IsNullOrEmpty($v)) { return ('<' + $Name + '>') }
    return $v
}

function Write-TkLog([string]$Level, [string]$Message) {
    if (-not $env:TK_LOGFILE) { return }
    try {
        $line = '{0} [{1}] [{2}] {3}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $script:TkMod, $Message
        $enc = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::AppendAllText($env:TK_LOGFILE, $line + "`r`n", $enc)
    } catch { }
}

function Test-TkAdmin {
    try {
        $id = [Security.Principal.WindowsIdentity]::GetCurrent()
        $pr = New-Object Security.Principal.WindowsPrincipal($id)
        return $pr.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch { return $false }
}

# --- Chiqarish yordamchilari ---------------------------------------------------
function Show-TkHeader([string]$Text) {
    try { Clear-Host } catch { }
    $c = $script:Col
    $bar = '=' * 72
    Write-Host ''
    Write-Host ('  ' + $c.Cyan + $bar + $c.Reset)
    Write-Host ('    ' + $c.White + $Text + $c.Reset)
    Write-Host ('  ' + $c.Cyan + $bar + $c.Reset)
    Write-Host ''
}

function Write-TkOk([string]$Text) {
    Write-Host ('  ' + $script:Col.Green + '[+]' + $script:Col.Reset + '  ' + $Text)
    Write-TkLog 'OK' $Text
}

function Write-TkErr([string]$Text) {
    Write-Host ('  ' + $script:Col.Red + '[x]' + $script:Col.Reset + '  ' + $Text)
    Write-TkLog 'ERROR' $Text
}

function Write-TkWarn([string]$Text) {
    Write-Host ('  ' + $script:Col.Yellow + '[*]' + $script:Col.Reset + '  ' + $Text)
    Write-TkLog 'WARN' $Text
}

function Write-TkInfo([string]$Text) {
    Write-Host ('  ' + $script:Col.Cyan + '[i]' + $script:Col.Reset + '  ' + $Text)
}

# ASK_YN juftligi. Qaytaradi: $true = Ha, $false = Yo'q / Esc / kirish yo'q
function Confirm-TkYesNo([string]$Text) {
    Write-Host ''
    Write-Host -NoNewline ('  ' + $Text + ' [Y/N]: ')
    while ($true) {
        try { $k = [Console]::ReadKey($true) } catch { Write-Host ''; return $false }
        if ($k.Key -eq 'Escape') { Write-Host 'N'; return $false }
        $ch = [string]$k.KeyChar
        if ($ch -match '^[yY]$') { Write-Host 'Y'; return $true }
        if ($ch -match '^[nN]$') { Write-Host 'N'; return $false }
    }
}

# Matn qatorini o'qish. EOF bo'lsa $null qaytaradi.
function Read-TkLine([string]$Prompt) {
    Write-Host -NoNewline ('  ' + $script:Col.Cyan + $Prompt + $script:Col.Reset + ' ')
    try { return [Console]::ReadLine() } catch { return $null }
}

function Wait-TkKey {
    Write-Host ''
    Write-Host ('  ' + $script:Col.Dim + (Get-TkText 'PRESS') + $script:Col.Reset)
    try { [void][Console]::ReadKey($true) } catch { }
}
