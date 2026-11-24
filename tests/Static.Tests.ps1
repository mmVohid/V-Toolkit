# Statik tekshiruvlar: kodlash, qator oxiri, sintaksis, yorliqlar, UZ/EN mosligi
BeforeDiscovery {
    $root = Split-Path -Parent $PSScriptRoot
    $files = @(Get-ChildItem -Path $root -Recurse -File -Include *.bat, *.ps1 |
               Where-Object { $_.FullName -notmatch '[\\/](\.git|tests)[\\/]' } |
               ForEach-Object { @{ Name = $_.FullName.Substring($root.Length + 1); Path = $_.FullName } })
    $bats = @($files | Where-Object { $_.Name -like '*.bat' })
    $pss  = @($files | Where-Object { $_.Name -like '*.ps1' })
}

BeforeAll {
    $script:Root = Split-Path -Parent $PSScriptRoot
    function Get-Labels([string]$Path) {
        $set = @{}
        foreach ($m in [regex]::Matches([IO.File]::ReadAllText($Path), '(?m)^:([A-Za-z0-9_]+)')) { $set[$m.Groups[1].Value.ToUpper()] = $true }
        return $set
    }
    function Get-LangKeys([string]$Text, [string]$Lang) {
        $other = 'EN'; if ($Lang -eq 'EN') { $other = 'UZ' }
        $m = [regex]::Match($Text, "(?ms)^:LANG_$Lang\r?\n(.*?)(?=^:LANG_$other|\z)")
        $keys = @()
        foreach ($k in [regex]::Matches($m.Groups[1].Value, '(?m)^set "(T_[A-Z0-9_]+)=')) { $keys += $k.Groups[1].Value }
        return $keys
    }
}

Describe 'Fayl gigiyenasi' {
    It '<Name> faqat ASCII' -ForEach ($bats + $pss) {
        $bytes = [IO.File]::ReadAllBytes($Path)
        $bad = @($bytes | Where-Object { $_ -gt 127 })
        $bad.Count | Should -Be 0
    }
    It '<Name> CRLF qator oxiri bilan' -ForEach ($bats + $pss) {
        $text = [IO.File]::ReadAllText($Path)
        [regex]::Matches($text, '(?<!\r)\n').Count | Should -Be 0
    }
    It '<Name> PowerShell sintaksisi to''g''ri' -ForEach $pss {
        $errs = $null; $tok = $null
        [void][System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tok, [ref]$errs)
        @($errs).Count | Should -Be 0 -Because (($errs | ForEach-Object { $_.Message + ' @' + $_.Extent.StartLineNumber }) -join '; ')
    }
}

Describe 'Batch yorliqlari' {
    It 'TOOLKIT.bat: barcha goto/call yorliqlari mavjud' {
        $p = Join-Path $script:Root 'TOOLKIT.bat'
        $text = [IO.File]::ReadAllText($p)
        $labels = Get-Labels $p
        $missing = @()
        foreach ($m in [regex]::Matches($text, '(?i)goto\s+:?([A-Za-z0-9_]+)')) {
            $t = $m.Groups[1].Value.ToUpper()
            if ($t -ne 'EOF' -and -not $labels.ContainsKey($t)) { $missing += $t }
        }
        $missing | Should -BeNullOrEmpty
    }
    It 'core.bat chaqiruvlari mavjud yorliqlarga ishora qiladi' {
        $core = Get-Labels (Join-Path $script:Root 'lib\core.bat')
        $missing = @()
        foreach ($f in @('TOOLKIT.bat', 'modules\ports.bat', 'modules\env.bat')) {
            $text = [IO.File]::ReadAllText((Join-Path $script:Root $f))
            foreach ($m in [regex]::Matches($text, '"!TK_C!"\s+:([A-Za-z0-9_]+)')) {
                $t = $m.Groups[1].Value.ToUpper()
                if (-not $core.ContainsKey($t) -and $t -ne 'LANG_') { $missing += "$f :$t" }
            }
        }
        $missing | Should -BeNullOrEmpty
    }
}

Describe 'UZ / EN matnlari' {
    It '<Name>: LANG_UZ va LANG_EN kalitlari bir xil' -ForEach (@('TOOLKIT.bat', 'lib\core.bat', 'modules\ports.bat', 'modules\env.bat') | ForEach-Object { @{ Name = $_ } }) {
        $text = [IO.File]::ReadAllText((Join-Path $script:Root $Name))
        $uz = @(Get-LangKeys $text 'UZ'); $en = @(Get-LangKeys $text 'EN')
        $uz.Count | Should -BeGreaterThan 0
        @(Compare-Object $uz $en) | Should -BeNullOrEmpty
    }
    It 'ishlatilgan T_ matnlari aniqlangan' {
        $defined = @{}
        foreach ($f in @('TOOLKIT.bat', 'lib\core.bat', 'modules\ports.bat', 'modules\env.bat')) {
            foreach ($m in [regex]::Matches([IO.File]::ReadAllText((Join-Path $script:Root $f)), '(?m)^set "(T_[A-Z0-9_]+)=')) { $defined[$m.Groups[1].Value] = $true }
        }
        $undefined = @()
        foreach ($f in @('TOOLKIT.bat', 'modules\ports.bat', 'modules\env.bat')) {
            foreach ($m in [regex]::Matches([IO.File]::ReadAllText((Join-Path $script:Root $f)), '!(T_[A-Z0-9_]+)!')) {
                if (-not $defined.ContainsKey($m.Groups[1].Value)) { $undefined += $m.Groups[1].Value }
            }
        }
        $undefined | Should -BeNullOrEmpty
    }
    It 'ps1 dagi Get-TkText kalitlari bat da aniqlangan' {
        $defined = @{}
        foreach ($f in @('lib\core.bat', 'modules\ports.bat', 'modules\env.bat')) {
            foreach ($m in [regex]::Matches([IO.File]::ReadAllText((Join-Path $script:Root $f)), '(?m)^set "T_([A-Z0-9_]+)=')) { $defined[$m.Groups[1].Value] = $true }
        }
        $missing = @()
        foreach ($f in @('modules\ports.ps1', 'modules\env.ps1', 'lib\core.ps1')) {
            foreach ($m in [regex]::Matches([IO.File]::ReadAllText((Join-Path $script:Root $f)), "Get-TkText\s+\(?'([A-Z0-9_]+)'")) {
                $key = $m.Groups[1].Value
                if ($key.EndsWith('_')) { continue }   # dinamik prefiks (P_CLS_ + sinf), pastda alohida tekshiriladi
                if (-not $defined.ContainsKey($key)) { $missing += $key }
            }
        }
        # dinamik: P_CLS_*, P_R_*  (ports.ps1)
        foreach ($d in 'P_CLS_PROTECTED', 'P_CLS_SERVICE', 'P_CLS_WARN', 'P_CLS_NORMAL', 'P_R_SYSTEM', 'P_R_SELF', 'P_R_SHARED', 'P_R_WARN') {
            if (-not $defined.ContainsKey($d)) { $missing += $d }
        }
        $missing | Should -BeNullOrEmpty
    }
}
