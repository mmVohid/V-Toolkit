# ======================================================================
#  modules\env.ps1 - .env tekshiruvchi (mantiq)
#  UI qobig'i va UZ/EN matnlar: modules\env.bat (LANG_UZ / LANG_EN)
#
#  Kirish (muhit): TK_ARG = papka (ixtiyoriy), TK_CI = 1 (ixtiyoriy), TK_CWD
#  Chiqish kodlari: 0 = toza, 1 = muammo bor, 2 = kirish xatosi
#
#  XAVFSIZLIK: qiymatlar hech qachon saqlanmaydi, ko'rsatilmaydi va logga yozilmaydi.
#  Parser faqat "qiymat bormi" (bool) ni eslab qoladi.
# ======================================================================
#requires -Version 5.1
$ErrorActionPreference = 'Stop'

$script:TkMod = 'env'
. (Join-Path (Split-Path -Parent $PSScriptRoot) 'lib\core.ps1')

$script:ExampleNames = @('.env.example', '.env.sample', '.env.template')
$script:TargetNames  = @('.env', '.env.local', '.env.development', '.env.production', '.env.test')
$script:MaxShow = 50

# --- Parser -----------------------------------------------------------------------
# Yopuvchi tirnoq indeksi (-1 = topilmadi). Qo'sh tirnoqda \ escape qiladi.
function Find-QuoteEnd([string]$Text, [string]$Q) {
    for ($k = 0; $k -lt $Text.Length; $k++) {
        $ch = [string]$Text[$k]
        if ($Q -eq '"' -and $ch -eq '\') { $k++; continue }
        if ($ch -eq $Q) { return $k }
    }
    return -1
}

# Qaytaradi: Entries (Key, HasValue), Invalid (qator raqamlari), Crlf
function Read-EnvFile([string]$Path) {
    $entries = New-Object System.Collections.ArrayList
    $invalid = New-Object System.Collections.ArrayList
    $text = [System.IO.File]::ReadAllText($Path)
    $crlf = $text.Contains("`r`n")
    $lines = $text -split '\r?\n'
    $i = 0
    while ($i -lt $lines.Count) {
        $lineNo = $i + 1
        $line = ([string]$lines[$i]).Trim()
        $i++
        if ($line -eq '' -or $line.StartsWith('#')) { continue }
        $line = $line -replace '^export\s+', ''
        $m = [regex]::Match($line, '^([A-Za-z_][A-Za-z0-9_.\-]*)\s*(=(.*))?$')
        if (-not $m.Success) { [void]$invalid.Add($lineNo); continue }

        $key = $m.Groups[1].Value
        $has = $false
        if ($m.Groups[2].Success) {
            $raw = $m.Groups[3].Value.Trim()
            if ($raw.StartsWith('"') -or $raw.StartsWith("'")) {
                $q = $raw.Substring(0, 1)
                $buf = $raw.Substring(1)
                $end = Find-QuoteEnd $buf $q
                $guard = 0
                # ko'p qatorli qiymat: yopuvchi tirnoq topilguncha keyingi qatorlarni qo'shamiz
                while ($end -lt 0 -and $i -lt $lines.Count -and $guard -lt 200) {
                    $buf = $buf + "`n" + [string]$lines[$i]
                    $i++
                    $guard++
                    $end = Find-QuoteEnd $buf $q
                }
                if ($end -ge 0) { $has = ($end -gt 0) } else { $has = ($buf.Length -gt 0) }
            } elseif ($raw.StartsWith('#')) {
                $has = $false
            } else {
                $val = ($raw -replace '\s+#.*$', '').Trim()
                $has = ($val.Length -gt 0)
            }
        }
        [void]$entries.Add([pscustomobject]@{ Key = $key; HasValue = $has })
    }
    return [pscustomobject]@{ Entries = $entries; Invalid = $invalid; Crlf = $crlf }
}

# --- Solishtirish -------------------------------------------------------------------
# Kalitlar registrga sezgir (System.Collections.Hashtable standart holatda shunday).
function Get-EnvReport([string]$ExamplePath, [string]$TargetPath) {
    $ex = Read-EnvFile $ExamplePath
    $exists = Test-Path -LiteralPath $TargetPath -PathType Leaf
    if ($exists) {
        $en = Read-EnvFile $TargetPath
    } else {
        $en = [pscustomobject]@{
            Entries = (New-Object System.Collections.ArrayList)
            Invalid = (New-Object System.Collections.ArrayList)
            Crlf    = $true
        }
    }

    $exMap = New-Object System.Collections.Hashtable
    foreach ($e in $ex.Entries) {
        if (-not $exMap.ContainsKey($e.Key)) { $exMap[$e.Key] = $e.HasValue }
        elseif ($e.HasValue) { $exMap[$e.Key] = $true }
    }

    $envMap = New-Object System.Collections.Hashtable
    $count  = New-Object System.Collections.Hashtable
    $order  = New-Object System.Collections.ArrayList
    foreach ($e in $en.Entries) {
        if ($count.ContainsKey($e.Key)) {
            $count[$e.Key] = [int]$count[$e.Key] + 1
            if ($e.HasValue) { $envMap[$e.Key] = $true }
        } else {
            $count[$e.Key] = 1
            $envMap[$e.Key] = $e.HasValue
            [void]$order.Add($e.Key)
        }
    }

    $missing = @(); $empty = @(); $extra = @(); $dups = @()
    $seen = New-Object System.Collections.Hashtable
    foreach ($e in $ex.Entries) {
        if ($seen.ContainsKey($e.Key)) { continue }
        $seen[$e.Key] = $true
        if (-not $envMap.ContainsKey($e.Key)) { $missing += $e.Key }
        elseif ((-not $envMap[$e.Key]) -and $exMap[$e.Key]) { $empty += $e.Key }
    }
    foreach ($k in $order) {
        if (-not $exMap.ContainsKey($k)) { $extra += $k }
        if ([int]$count[$k] -gt 1) { $dups += $k }
    }

    $problems = $missing.Count + $empty.Count + $dups.Count + $en.Invalid.Count
    return [pscustomobject]@{
        Ex = $ex; En = $en; TargetExists = $exists; ExCount = $seen.Count
        Missing = $missing; Empty = $empty; Extra = $extra; Dups = $dups
        Problems = $problems
    }
}

# --- Ko'rsatish ---------------------------------------------------------------------
function Show-KeyList([string]$Tag, [string]$Color, [string]$DescKey, $Keys) {
    $keys = @($Keys)
    if ($keys.Count -eq 0) { return }
    $c = $script:Col
    Write-Host ('  ' + $Color + (Format-Fit $Tag 10) + $c.Reset + (Format-Fit ([string]$keys.Count) 4) +
                $c.Dim + (Get-TkText $DescKey) + $c.Reset)
    $shown = 0
    foreach ($k in $keys) {
        if ($shown -ge $script:MaxShow) { break }
        Write-Host ('      ' + $k)
        $shown++
    }
    if ($keys.Count -gt $script:MaxShow) {
        Write-Host ('      ' + $c.Dim + ((Get-TkText 'E_MORE') -f ($keys.Count - $script:MaxShow)) + $c.Reset)
    }
    Write-Host ''
}

# Yetishmayotgan kalitlarni bo'sh qiymat bilan qo'shadi. Mavjud fayl bo'lsa avval zaxira.
# Qaytaradi: zaxira yo'li ('' = fayl yangi yaratildi)
function Add-MissingKeys([string]$TargetPath, $Report) {
    $nl = "`r`n"
    if (-not $Report.En.Crlf) { $nl = "`n" }
    $enc = New-Object System.Text.UTF8Encoding($false)
    $lines = @()
    foreach ($k in $Report.Missing) { $lines += ($k + '=') }
    $body = ($lines -join $nl) + $nl

    if (-not $Report.TargetExists) {
        [System.IO.File]::WriteAllText($TargetPath, $body, $enc)
        return ''
    }
    $bak = $TargetPath + '.bak'
    if (Test-Path -LiteralPath $bak) { $bak = $TargetPath + '.bak-' + (Get-Date -Format 'yyyyMMddHHmmss') }
    Copy-Item -LiteralPath $TargetPath -Destination $bak -ErrorAction Stop
    $existing = [System.IO.File]::ReadAllText($TargetPath)
    $prefix = ''
    if ($existing.Length -gt 0 -and -not $existing.EndsWith("`n")) { $prefix = $nl }
    [System.IO.File]::AppendAllText($TargetPath, $prefix + $body, $enc)
    return $bak
}

# Bitta papkani tekshiradi. Qaytaradi: 0 = toza, 1 = muammo, 2 = kirish xatosi
function Invoke-EnvCheck([string]$Dir, [bool]$Ci) {
    $c = $script:Col
    if (-not (Test-Path -LiteralPath $Dir -PathType Container)) {
        Write-TkErr ((Get-TkText 'E_NODIR') + ' ' + $Dir)
        return 2
    }
    $examplePath = $null
    foreach ($n in $script:ExampleNames) {
        $p = Join-Path $Dir $n
        if (Test-Path -LiteralPath $p -PathType Leaf) { $examplePath = $p; break }
    }
    if ($null -eq $examplePath) {
        Write-TkErr (Get-TkText 'E_NOEX')
        return 2
    }

    $targets = @()
    foreach ($n in $script:TargetNames) {
        $p = Join-Path $Dir $n
        if (Test-Path -LiteralPath $p -PathType Leaf) { $targets += $p }
    }
    $targetPath = Join-Path $Dir '.env'
    if ($targets.Count -ge 1) { $targetPath = $targets[0] }
    if ($targets.Count -gt 1 -and -not $Ci) {
        for ($i = 0; $i -lt $targets.Count; $i++) {
            Write-Host ('    ' + $c.Cyan + '[' + ($i + 1) + ']' + $c.Reset + ' ' + (Split-Path -Leaf $targets[$i]))
        }
        $ans = Read-TkLine (Get-TkText 'E_PICK')
        $idx = 0
        if ($null -ne $ans -and [int]::TryParse($ans.Trim(), [ref]$idx) -and $idx -ge 1 -and $idx -le $targets.Count) {
            $targetPath = $targets[$idx - 1]
        }
        Write-Host ''
    }

    $exLeaf = Split-Path -Leaf $examplePath
    $tgLeaf = Split-Path -Leaf $targetPath
    Write-TkInfo ((Get-TkText 'E_COMPARE') -f $exLeaf, $tgLeaf)
    Write-Host ('  ' + $c.Dim + (Get-TkText 'E_NOVALUES') + $c.Reset)
    Write-Host ''

    $rep = Get-EnvReport $examplePath $targetPath
    if (-not $rep.TargetExists) { Write-TkWarn ((Get-TkText 'E_NOTARGET') -f $tgLeaf) }

    Show-KeyList 'MISSING'   $c.Red    'E_D_MISSING'   $rep.Missing
    Show-KeyList 'EMPTY'     $c.Yellow 'E_D_EMPTY'     $rep.Empty
    Show-KeyList 'DUPLICATE' $c.Yellow 'E_D_DUPLICATE' $rep.Dups
    Show-KeyList 'EXTRA'     $c.Cyan   'E_D_EXTRA'     $rep.Extra
    if ($rep.En.Invalid.Count -gt 0) {
        $nums = (@($rep.En.Invalid | Select-Object -First 20) -join ', ')
        Write-TkWarn ((Get-TkText 'E_INVALID') -f $nums)
    }

    Write-Host ('  ' + $c.Dim + ((Get-TkText 'E_SUMMARY') -f $rep.ExCount, $rep.Missing.Count, $rep.Empty.Count, $rep.Extra.Count, $rep.Dups.Count) + $c.Reset)
    Write-TkLog 'INFO' ("check example=$exLeaf target=$tgLeaf keys=$($rep.ExCount) missing=$($rep.Missing.Count) empty=$($rep.Empty.Count) extra=$($rep.Extra.Count) duplicate=$($rep.Dups.Count) invalid=$($rep.En.Invalid.Count)")

    $problems = $rep.Problems

    # Tuzatish taklifi (faqat interaktiv rejimda)
    if (-not $Ci -and $rep.Missing.Count -gt 0) {
        $askKey = 'E_ASK_FIX'
        if (-not $rep.TargetExists) { $askKey = 'E_ASK_CREATE' }
        if (Confirm-TkYesNo ((Get-TkText $askKey) -f $rep.Missing.Count, $tgLeaf)) {
            try {
                Write-TkLog 'ACTION' ("add-missing-keys target=$tgLeaf count=$($rep.Missing.Count)")
                $bak = Add-MissingKeys $targetPath $rep
                Write-TkOk ((Get-TkText 'E_FIXED') + ' ' + $rep.Missing.Count)
                if ($bak -ne '') {
                    Write-TkInfo ((Get-TkText 'E_BACKUP') + ' ' + (Split-Path -Leaf $bak))
                    Write-TkWarn (Get-TkText 'E_BAK_NOTE')
                }
                $rep2 = Get-EnvReport $examplePath $targetPath
                $problems = $rep2.Problems
            } catch {
                Write-TkErr ((Get-TkText 'E_FIX_FAIL') + ' ' + $_.Exception.Message)
            }
        } else {
            Write-TkInfo (Get-TkText 'CANCELLED')
        }
    }

    Write-Host ''
    if ($problems -eq 0) {
        Write-TkOk (Get-TkText 'E_CLEAN')
        return 0
    }
    Write-TkWarn (Get-TkText 'E_PROBLEMS')
    return 1
}

# --- Papka tanlash va holat ---------------------------------------------------------------
function Resolve-Dir([string]$Text, [string]$Base) {
    $t = $Text.Trim().Trim('"')
    try { return [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($Base, $t)) } catch { return $t }
}

function Get-LastDirFile { return (Join-Path $env:LOCALAPPDATA 'VohidToolkit\env.last') }

function Get-LastDir {
    try {
        $f = Get-LastDirFile
        if (Test-Path -LiteralPath $f) {
            $d = ([System.IO.File]::ReadAllText($f)).Trim()
            if ($d -ne '' -and (Test-Path -LiteralPath $d -PathType Container)) { return $d }
        }
    } catch { }
    return $null
}

function Save-LastDir([string]$Dir) {
    try {
        $f = Get-LastDirFile
        $parent = Split-Path -Parent $f
        if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
        [System.IO.File]::WriteAllText($f, $Dir, (New-Object System.Text.UTF8Encoding($false)))
    } catch { }
}

function Start-EnvInteractive([string]$Base) {
    $dir = Get-LastDir
    if ($null -eq $dir) { $dir = $Base }
    $ask = $true
    while ($true) {
        if ($ask) {
            Show-TkHeader (Get-TkText 'E_TITLE')
            $raw = Read-TkLine ((Get-TkText 'E_PROMPT_DIR') -f $dir)
            if ($null -eq $raw) { return 0 }
            $s = $raw.Trim()
            if ($s -eq '0') { return 0 }
            if ($s -ne '') { $dir = Resolve-Dir $s $Base }
            $ask = $false
        }
        Show-TkHeader (Get-TkText 'E_TITLE')
        $rc = [int](@(Invoke-EnvCheck $dir $false) | Select-Object -Last 1)
        if ($rc -ne 2) { Save-LastDir $dir }

        Write-Host ''
        Write-Host ('  ' + $script:Col.Dim + (Get-TkText 'E_HINT') + $script:Col.Reset)
        $a = Read-TkLine '>>'
        if ($null -eq $a) { return 0 }
        $t = $a.Trim()
        if ($t -eq '0' -or $t -ieq 'q') { return 0 }
        if ($t -ieq 'd') { $ask = $true }
    }
}

# --- Kirish nuqtasi ---------------------------------------------------------------------------
try {
    Write-TkLog 'INFO' 'module start'
    $ci = ($env:TK_CI -eq '1')
    $base = $env:TK_CWD
    if ([string]::IsNullOrEmpty($base)) { $base = (Get-Location).Path }

    $code = 0
    if ($ci -or -not [string]::IsNullOrEmpty($env:TK_ARG)) {
        $dir = $base
        if (-not [string]::IsNullOrEmpty($env:TK_ARG)) { $dir = Resolve-Dir $env:TK_ARG $base }
        if (-not $ci) { Show-TkHeader (Get-TkText 'E_TITLE') }
        $code = [int](@(Invoke-EnvCheck $dir $ci) | Select-Object -Last 1)
    } else {
        $code = [int](@(Start-EnvInteractive $base) | Select-Object -Last 1)
    }
    Write-TkLog 'INFO' "module exit code=$code"
    exit $code
} catch {
    Write-TkErr ((Get-TkText 'E_FAIL') + ' ' + $_.Exception.Message)
    exit 2
}
