# ======================================================================
#  modules\changelog.ps1 - Git changelog / release notes (mantiq)
#  UI qobig'i va UZ/EN matnlar: modules\changelog.bat (LANG_UZ / LANG_EN)
#
#  Kirish (muhit): TK_ARG = papka (ixtiyoriy), TK_CI = 1 (ixtiyoriy), TK_CWD
#  Chiqish kodlari: 0 = muvaffaqiyat (commit yo'q bo'lsa ham), 2 = kirish xatosi
#
#  Oraliq: oxirgi tegdan HEAD gacha (teg bo'lmasa - butun tarix).
#  Agar HEAD aynan tegda tursa, oldingi teg dan shu teggacha olinadi.
#  Guruhlash: Conventional Commits (feat, fix, perf, ...). Boshqalari "Other".
#  Faqat sarlavha (subject) o'qiladi; git faqat argumentlar massivi bilan chaqiriladi.
# ======================================================================
#requires -Version 5.1
[CmdletBinding()]
param([switch]$NoRun)   # testlar uchun
$ErrorActionPreference = 'Stop'

$script:TkMod = 'changelog'
. (Join-Path (Split-Path -Parent $PSScriptRoot) 'lib\core.ps1')

$script:OutFile = 'RELEASE_NOTES.md'
$script:SectionOrder = @('breaking', 'feat', 'fix', 'perf', 'refactor', 'docs', 'test', 'ci', 'build', 'style', 'chore', 'other')
$script:TypeToSection = @{
    feat = 'feat'; fix = 'fix'; perf = 'perf'; refactor = 'refactor'; docs = 'docs'; test = 'test'
    ci = 'ci'; build = 'build'; style = 'style'; chore = 'chore'
}

# --- Git -------------------------------------------------------------------------
function Invoke-Git([string]$Dir, [string[]]$GitArgs) {
    # Qaytaradi: @{ Code; Lines }. Hech qachon shell orqali emas.
    $out = & git -C $Dir @GitArgs 2>$null
    $code = $LASTEXITCODE
    return [pscustomobject]@{ Code = $code; Lines = @($out) }
}

function Test-GitAvailable { return [bool](Get-Command git -ErrorAction SilentlyContinue) }

function Test-GitRepo([string]$Dir) {
    if (-not (Test-Path -LiteralPath $Dir -PathType Container)) { return $false }
    $r = Invoke-Git $Dir @('rev-parse', '--is-inside-work-tree')
    return ($r.Code -eq 0 -and ($r.Lines -join '') -eq 'true')
}

function Test-HasCommits([string]$Dir) {
    return ((Invoke-Git $Dir @('rev-parse', '--verify', '-q', 'HEAD')).Code -eq 0)
}

# Oraliq: @{ From = <teg|$null>; Label = <matn> }
function Get-ChangelogRange([string]$Dir) {
    $head = Invoke-Git $Dir @('rev-parse', 'HEAD')
    $d = Invoke-Git $Dir @('describe', '--tags', '--abbrev=0')
    if ($d.Code -ne 0 -or $d.Lines.Count -eq 0) { return @{ From = $null; To = 'HEAD'; Label = $null } }
    $tag = [string]$d.Lines[0]
    $tagCommit = Invoke-Git $Dir @('rev-list', '-n', '1', $tag)
    if ($tagCommit.Code -eq 0 -and $tagCommit.Lines.Count -gt 0 -and $head.Lines.Count -gt 0 -and [string]$tagCommit.Lines[0] -eq [string]$head.Lines[0]) {
        # HEAD aynan tegda: oldingi tegdan shu teggacha
        $p = Invoke-Git $Dir @('describe', '--tags', '--abbrev=0', ($tag + '^'))
        $prev = $null
        if ($p.Code -eq 0 -and $p.Lines.Count -gt 0) { $prev = [string]$p.Lines[0] }
        return @{ From = $prev; To = $tag; Label = $tag }
    }
    return @{ From = $tag; To = 'HEAD'; Label = $null }
}

function Get-RangeCommits([string]$Dir, $Range) {
    $spec = $Range.To
    if ($Range.From) { $spec = $Range.From + '..' + $Range.To }
    $r = Invoke-Git $Dir @('log', '--no-merges', '--pretty=format:%h%x1f%s', $spec)
    if ($r.Code -ne 0) { return @() }
    $list = New-Object System.Collections.Generic.List[object]
    foreach ($ln in $r.Lines) {
        $s = [string]$ln
        if ($s.Trim() -eq '') { continue }
        $parts = $s.Split([char]0x1f, 2)
        if ($parts.Count -lt 2) { continue }
        $list.Add([pscustomobject]@{ Hash = $parts[0]; Subject = $parts[1] })
    }
    return $list.ToArray()
}

# --- Conventional Commits ---------------------------------------------------------
# Qaytaradi: @{ Section; Scope; Text; Breaking }
function ConvertFrom-CommitSubject([string]$Subject) {
    $s = $Subject.Trim()
    $m = [regex]::Match($s, '^(?<t>[A-Za-z]+)(\((?<s>[^)]*)\))?(?<b>!)?:\s*(?<d>.+)$')
    if ($m.Success) {
        $t = $m.Groups['t'].Value.ToLowerInvariant()
        if ($script:TypeToSection.ContainsKey($t)) {
            $brk = $m.Groups['b'].Success
            $sec = $script:TypeToSection[$t]
            if ($brk) { $sec = 'breaking' }
            return @{ Section = $sec; Scope = $m.Groups['s'].Value; Text = $m.Groups['d'].Value.Trim(); Breaking = $brk }
        }
    }
    return @{ Section = 'other'; Scope = ''; Text = $s; Breaking = $false }
}

# --- Markdown ------------------------------------------------------------------
function Build-Changelog($Commits, [string]$Label, [string]$Date) {
    $groups = @{}
    foreach ($c in $Commits) {
        $p = ConvertFrom-CommitSubject $c.Subject
        if (-not $groups.ContainsKey($p.Section)) { $groups[$p.Section] = New-Object System.Collections.Generic.List[string] }
        $line = '- '
        if ($p.Scope) { $line += '**' + $p.Scope + ':** ' }
        $line += $p.Text + ' (`' + $c.Hash + '`)'
        $groups[$p.Section].Add($line)
    }
    $nl = "`n"
    $title = $Label
    if ([string]::IsNullOrEmpty($title)) { $title = Get-TkText 'C_UNRELEASED' }
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.Append('## ' + $title + ' - ' + $Date + $nl)
    foreach ($sec in $script:SectionOrder) {
        if (-not $groups.ContainsKey($sec)) { continue }
        [void]$sb.Append($nl + '### ' + (Get-TkText ('C_S_' + $sec.ToUpperInvariant())) + $nl + $nl)
        foreach ($l in $groups[$sec]) { [void]$sb.Append($l + $nl) }
    }
    return $sb.ToString()
}

function Get-SectionCounts($Commits) {
    $n = @{}
    foreach ($c in $Commits) {
        $s = (ConvertFrom-CommitSubject $c.Subject).Section
        if ($n.ContainsKey($s)) { $n[$s]++ } else { $n[$s] = 1 }
    }
    return $n
}

# --- Fayl yozish ---------------------------------------------------------------------
# Mavjud bo'lsa ASK_YN bilan tasdiq; yangi blok faylning boshiga qo'shiladi, eski mazmun saqlanadi.
function Write-ReleaseNotes([string]$Dir, [string]$Markdown, [bool]$Interactive) {
    $path = Join-Path $Dir $script:OutFile
    $enc = New-Object System.Text.UTF8Encoding($false)
    $new = $Markdown
    if (Test-Path -LiteralPath $path) {
        if (-not $Interactive) { return $false }
        if (-not (Confirm-TkYesNo ((Get-TkText 'C_ASK_PREPEND').Replace('{0}', $script:OutFile)))) { return $false }
        $old = [System.IO.File]::ReadAllText($path)
        $new = $Markdown + "`n" + $old
    } elseif ($Interactive) {
        if (-not (Confirm-TkYesNo ((Get-TkText 'C_ASK_CREATE').Replace('{0}', $script:OutFile)))) { return $false }
    }
    try {
        [System.IO.File]::WriteAllText($path, $new, $enc)
        return $true
    } catch {
        Write-TkErr ((Get-TkText 'C_WRITE_FAIL') + ' ' + $path)
        return $false
    }
}

# --- Asosiy oqim -------------------------------------------------------------------
# Qaytaradi: 0 = ok, 2 = kirish xatosi
function Invoke-Changelog([string]$Dir, [bool]$Ci) {
    if (-not (Test-GitAvailable)) { Write-TkErr (Get-TkText 'C_NOGIT'); return 2 }
    if (-not (Test-GitRepo $Dir)) { Write-TkErr ((Get-TkText 'C_NOREPO') + ' ' + $Dir); return 2 }
    if (-not (Test-HasCommits $Dir)) { Write-TkWarn (Get-TkText 'C_NOCOMMITS'); return 0 }

    $range = Get-ChangelogRange $Dir
    $commits = @(Get-RangeCommits $Dir $range)
    $fromTxt = $range.From
    if (-not $fromTxt) { $fromTxt = (Get-TkText 'C_START') }
    if (-not $Ci) { Write-TkInfo ((Get-TkText 'C_RANGE').Replace('{0}', [string]$fromTxt).Replace('{1}', [string]$range.To)) }

    if ($commits.Count -eq 0) { Write-TkWarn (Get-TkText 'C_EMPTY'); Write-TkLog 'INFO' 'no commits in range'; return 0 }

    $md = Build-Changelog $commits $range.Label (Get-Date -Format 'yyyy-MM-dd')
    Write-TkLog 'INFO' ("commits=" + $commits.Count)

    if ($Ci) {
        # stdout ga toza markdown (UTF-8), fayl yozilmaydi
        [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
        [Console]::Out.Write($md)
        return 0
    }

    Write-Host ''
    Write-Host $md
    Write-TkInfo ((Get-TkText 'C_TOTAL').Replace('{0}', [string]$commits.Count))
    if (Write-ReleaseNotes $Dir $md $true) {
        Write-TkOk ((Get-TkText 'C_SAVED') + ' ' + (Join-Path $Dir $script:OutFile))
        Write-TkLog 'ACTION' ("wrote " + $script:OutFile)
    }
    return 0
}

function Resolve-Dir([string]$Text, [string]$Base) {
    $t = $Text.Trim().Trim('"')
    try { return [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($Base, $t)) } catch { return $t }
}

function Start-ChangelogInteractive([string]$Base) {
    $dir = $Base
    while ($true) {
        Show-TkHeader (Get-TkText 'C_TITLE')
        $rc = [int](@(Invoke-Changelog $dir $false) | Select-Object -Last 1)
        Write-Host ''
        Write-Host ('  ' + $script:Col.Dim + (Get-TkText 'C_HINT') + $script:Col.Reset)
        $a = Read-TkLine '>>'
        if ($null -eq $a) { return $rc }
        $t = $a.Trim()
        if ($t -eq '0' -or $t -ieq 'q' -or $t -eq '') { return 0 }
        if ($t -ieq 'd') {
            $x = Read-TkLine ((Get-TkText 'C_PROMPT_DIR').Replace('{0}', $dir))
            if ($null -ne $x -and $x.Trim() -ne '' -and $x.Trim() -ne '0') { $dir = Resolve-Dir $x $Base }
        }
    }
}

# --- Kirish nuqtasi -----------------------------------------------------------------
if ($NoRun) { return }

try {
    Write-TkLog 'INFO' 'module start'
    $ci = ($env:TK_CI -eq '1')
    $base = $env:TK_CWD
    if ([string]::IsNullOrEmpty($base)) { $base = (Get-Location).Path }

    $code = 0
    if ($ci -or -not [string]::IsNullOrEmpty($env:TK_ARG)) {
        $dir = $base
        if (-not [string]::IsNullOrEmpty($env:TK_ARG)) { $dir = Resolve-Dir $env:TK_ARG $base }
        if (-not $ci) { Show-TkHeader (Get-TkText 'C_TITLE') }
        $code = [int](@(Invoke-Changelog $dir $ci) | Select-Object -Last 1)
    } else {
        $code = [int](@(Start-ChangelogInteractive $base) | Select-Object -Last 1)
    }
    Write-TkLog 'INFO' "module exit code=$code"
    exit $code
} catch {
    Write-TkErr ((Get-TkText 'C_FAIL') + ' ' + $_.Exception.Message)
    exit 2
}
