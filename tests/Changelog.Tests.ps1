# Git changelog mantig'i (modules\changelog.ps1 funksiyalari) + CLI
BeforeAll {
    $root = Split-Path -Parent $PSScriptRoot
    . (Join-Path $root 'modules\changelog.ps1') -NoRun
    # matnlarni modul .bat fayldan (EN) o'qib muhitga qo'yamiz
    $inEn = $false
    foreach ($ln in Get-Content -LiteralPath (Join-Path $root 'modules\changelog.bat')) {
        if ($ln -match '^:LANG_EN') { $inEn = $true; continue }
        if ($inEn -and $ln -match '^set "(T_C_[A-Z_]+)=(.*)"\s*$') { [Environment]::SetEnvironmentVariable($Matches[1], $Matches[2]) }
    }
    $script:Root = $root

    function New-Repo([string[]]$Subjects, [string]$TagAfter) {
        $d = Join-Path ([IO.Path]::GetTempPath()) ('tkcl_' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $d | Out-Null
        & git -C $d init -q 2>&1 | Out-Null
        & git -C $d config user.email 't@t.t'; & git -C $d config user.name 't'
        & git -C $d config commit.gpgsign false
        $i = 0
        foreach ($s in $Subjects) {
            $i++
            Set-Content -LiteralPath (Join-Path $d "f$i.txt") -Value $i
            & git -C $d add -A 2>&1 | Out-Null
            & git -C $d commit -q -m $s 2>&1 | Out-Null
            if ($s -eq $TagAfter) { & git -C $d tag 'v1.0.0' 2>&1 | Out-Null }
        }
        return $d
    }
}

Describe 'ConvertFrom-CommitSubject' {
    It 'feat(scope): matn' {
        $p = ConvertFrom-CommitSubject 'feat(ports): add dashboard'
        $p.Section | Should -Be 'feat'; $p.Scope | Should -Be 'ports'; $p.Text | Should -Be 'add dashboard'
    }
    It 'fix: scope siz' {
        (ConvertFrom-CommitSubject 'fix: crash on EOF').Section | Should -Be 'fix'
    }
    It '! belgisi buzuvchi o''zgarish' {
        $p = ConvertFrom-CommitSubject 'feat!: drop v1 config'
        $p.Section | Should -Be 'breaking'; $p.Breaking | Should -BeTrue
    }
    It 'noma''lum yoki formatsiz sarlavha: other' {
        (ConvertFrom-CommitSubject 'Update README').Section | Should -Be 'other'
        (ConvertFrom-CommitSubject 'wip: something').Section | Should -Be 'other'
    }
    It 'katta-kichik harf farqsiz' {
        (ConvertFrom-CommitSubject 'FIX: x').Section | Should -Be 'fix'
    }
}

Describe 'Build-Changelog' {
    It 'bo''limlar tartibi: breaking, feat, fix, other' {
        $c = @(
            [pscustomobject]@{ Hash = 'a1'; Subject = 'chore: bump' }
            [pscustomobject]@{ Hash = 'b2'; Subject = 'fix(env): dup keys' }
            [pscustomobject]@{ Hash = 'c3'; Subject = 'feat!: new cli' }
            [pscustomobject]@{ Hash = 'd4'; Subject = 'random message' }
        )
        $md = Build-Changelog $c 'v1.1.0' '2026-01-02'
        $md | Should -Match '^## v1.1.0 - 2026-01-02'
        $i1 = $md.IndexOf('### Breaking changes'); $i2 = $md.IndexOf('### Fixes'); $i3 = $md.IndexOf('### Chores'); $i4 = $md.IndexOf('### Other')
        $i1 | Should -BeGreaterThan -1
        $i1 | Should -BeLessThan $i2
        $i2 | Should -BeLessThan $i3
        $i3 | Should -BeLessThan $i4
        $md | Should -Match '\*\*env:\*\* dup keys \(`b2`\)'
    }
    It 'teg bo''lmasa: Unreleased' {
        $md = Build-Changelog @([pscustomobject]@{ Hash = 'a'; Subject = 'fix: x' }) $null '2026-01-02'
        $md | Should -Match '^## Unreleased'
    }
    It 'bo''sh bo''limlar chiqmaydi' {
        $md = Build-Changelog @([pscustomobject]@{ Hash = 'a'; Subject = 'fix: x' }) 'v1' '2026-01-02'
        $md | Should -Not -Match '### Features'
    }
}

Describe 'git bilan: oraliq' -Skip:(-not (Get-Command git -ErrorAction SilentlyContinue)) {
    It 'teg yo''q: butun tarix, From = null' {
        $d = New-Repo @('feat: a', 'fix: b') ''
        try {
            $r = Get-ChangelogRange $d
            $r.From | Should -BeNullOrEmpty
            @(Get-RangeCommits $d $r).Count | Should -Be 2
        } finally { Remove-Item -LiteralPath $d -Recurse -Force -ErrorAction SilentlyContinue }
    }
    It 'tegdan keyingi commitlar faqat' {
        $d = New-Repo @('feat: a', 'fix: b', 'docs: c', 'test: d') 'fix: b'
        try {
            $r = Get-ChangelogRange $d
            $r.From | Should -Be 'v1.0.0'
            $c = @(Get-RangeCommits $d $r)
            $c.Count | Should -Be 2
            ($c | ForEach-Object Subject) -join '|' | Should -Be 'test: d|docs: c'
        } finally { Remove-Item -LiteralPath $d -Recurse -Force -ErrorAction SilentlyContinue }
    }
    It 'HEAD aynan tegda: oldingi tegdan shu teggacha (teg bitta bo''lsa butun tarix)' {
        $d = New-Repo @('feat: a', 'fix: b') 'fix: b'
        try {
            $r = Get-ChangelogRange $d
            $r.Label | Should -Be 'v1.0.0'
            @(Get-RangeCommits $d $r).Count | Should -Be 2
        } finally { Remove-Item -LiteralPath $d -Recurse -Force -ErrorAction SilentlyContinue }
    }
    It 'git repozitoriy emas: Test-GitRepo = false' {
        $d = Join-Path ([IO.Path]::GetTempPath()) ('tkno_' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $d | Out-Null
        try { Test-GitRepo $d | Should -BeFalse } finally { Remove-Item -LiteralPath $d -Recurse -Force }
    }
    It 'Write-ReleaseNotes: mavjud fayl CI rejimida o''zgarmaydi' {
        $d = New-Repo @('feat: a') ''
        try {
            Set-Content -LiteralPath (Join-Path $d 'RELEASE_NOTES.md') -Value 'OLD'
            Write-ReleaseNotes $d '## x' $false | Should -BeFalse
            (Get-Content -LiteralPath (Join-Path $d 'RELEASE_NOTES.md') -Raw).Trim() | Should -Be 'OLD'
        } finally { Remove-Item -LiteralPath $d -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

Describe 'changelog CLI (--ci)' -Skip:(-not (Get-Command git -ErrorAction SilentlyContinue)) {
    BeforeAll {
        function Invoke-Tk([string]$ArgLine) {
            $psi = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName = 'cmd.exe'
            $psi.Arguments = '/d /s /c ""' + (Join-Path $script:Root 'TOOLKIT.bat') + '" ' + $ArgLine + '"'
            $psi.UseShellExecute = $false
            $psi.RedirectStandardInput = $true; $psi.RedirectStandardOutput = $true; $psi.RedirectStandardError = $true
            $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
            $psi.WorkingDirectory = $script:Root
            $p = [System.Diagnostics.Process]::Start($psi)
            $p.StandardInput.Close()
            $so = $p.StandardOutput.ReadToEndAsync(); $se = $p.StandardError.ReadToEndAsync()
            if (-not $p.WaitForExit(40000)) { & taskkill.exe /T /F /PID $p.Id 2>&1 | Out-Null; return [pscustomobject]@{ Code = -999; Text = 'TIMEOUT' } }
            [pscustomobject]@{ Code = $p.ExitCode; Text = ($so.Result + $se.Result) }
        }
    }
    It 'repo emas: kod 2' {
        $d = Join-Path ([IO.Path]::GetTempPath()) ('tkno_' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $d | Out-Null
        try {
            $r = Invoke-Tk ('changelog "' + $d + '" --ci --lang EN')
            $r.Code | Should -Be 2 -Because $r.Text
        } finally { Remove-Item -LiteralPath $d -Recurse -Force }
    }
    It 'repo: markdown stdout ga, kod 0, fayl yozilmaydi' {
        $d = New-Repo @('feat(x): hello', 'fix: world') ''
        try {
            $r = Invoke-Tk ('changelog "' + $d + '" --ci --lang EN')
            $r.Code | Should -Be 0 -Because $r.Text
            $r.Text | Should -Match '### Features'
            $r.Text | Should -Match 'hello'
            Test-Path (Join-Path $d 'RELEASE_NOTES.md') | Should -BeFalse
        } finally { Remove-Item -LiteralPath $d -Recurse -Force -ErrorAction SilentlyContinue }
    }
}
