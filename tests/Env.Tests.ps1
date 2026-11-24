# .env parser va solishtirish mantig'i (modules\env.ps1 funksiyalari)
BeforeAll {
    $root = Split-Path -Parent $PSScriptRoot
    . (Join-Path $root 'modules\env.ps1') -NoRun
    $script:Fx = Join-Path $PSScriptRoot 'fixtures\env'
}

Describe 'Read-EnvFile' {
    It 'kalitlar, export, izoh, qo''shtirnoq va ko''p qatorli qiymatni tushunadi' {
        $r = Read-EnvFile (Join-Path $script:Fx 'bad\.env.example')
        @($r.Entries | ForEach-Object Key) | Should -Be @('APP_NAME', 'PORT', 'DB_URL', 'JWT_SECRET', 'MULTI', 'QUOTED', 'EMPTYQ', 'OPTIONAL')
        $r.Invalid.Count | Should -Be 0
        ($r.Entries | Where-Object Key -eq 'MULTI').HasValue   | Should -BeTrue
        ($r.Entries | Where-Object Key -eq 'QUOTED').HasValue  | Should -BeTrue
        ($r.Entries | Where-Object Key -eq 'EMPTYQ').HasValue  | Should -BeFalse
        ($r.Entries | Where-Object Key -eq 'OPTIONAL').HasValue | Should -BeFalse
    }
    It 'noto''g''ri qator raqamini qaytaradi (mazmunni emas)' {
        $r = Read-EnvFile (Join-Path $script:Fx 'bad\.env')
        @($r.Invalid) | Should -Be @(10)
    }
    It 'qiymatlar natija obyektida saqlanmaydi' {
        $r = Read-EnvFile (Join-Path $script:Fx 'bad\.env')
        ($r | ConvertTo-Json -Depth 5) | Should -Not -Match 'TOP_SECRET_VALUE_999|again_SECRET_2'
    }
}

Describe 'Get-EnvReport' {
    It 'toza juftlik: muammo yo''q' {
        $rep = Get-EnvReport (Join-Path $script:Fx 'ok\.env.example') (Join-Path $script:Fx 'ok\.env')
        $rep.Problems | Should -Be 0
        @($rep.Missing).Count | Should -Be 0
    }
    It 'MISSING / EMPTY / EXTRA / DUPLICATE ni to''g''ri ajratadi' {
        $rep = Get-EnvReport (Join-Path $script:Fx 'bad\.env.example') (Join-Path $script:Fx 'bad\.env')
        @($rep.Missing) | Should -Be @('DB_URL', 'OPTIONAL')
        @($rep.Empty)   | Should -Be @('PORT')
        @($rep.Extra)   | Should -Be @('LEGACY')
        @($rep.Dups)    | Should -Be @('JWT_SECRET')
        $rep.ExCount    | Should -Be 8
        $rep.Problems   | Should -Be 5   # 2 missing + 1 empty + 1 dup + 1 invalid (EXTRA hisoblanmaydi)
    }
    It '.env yo''q bo''lsa barcha namuna kalitlari MISSING' {
        $rep = Get-EnvReport (Join-Path $script:Fx 'bad\.env.example') (Join-Path $TestDrive 'nope.env')
        $rep.TargetExists | Should -BeFalse
        @($rep.Missing).Count | Should -Be 8
    }
    It 'kalitlar registrga sezgir' {
        $ex = Join-Path $TestDrive 'a.example'; $en = Join-Path $TestDrive 'a.env'
        Set-Content -LiteralPath $ex -Value 'Key=1' -Encoding ASCII
        Set-Content -LiteralPath $en -Value 'KEY=1' -Encoding ASCII
        $rep = Get-EnvReport $ex $en
        @($rep.Missing) | Should -Be @('Key')
        @($rep.Extra)   | Should -Be @('KEY')
    }
}

Describe 'Add-MissingKeys' {
    It 'zaxira yaratadi va faqat bo''sh kalitlarni qo''shadi' {
        $dir = Join-Path $TestDrive 'proj'; New-Item -ItemType Directory -Path $dir | Out-Null
        Copy-Item (Join-Path $script:Fx 'bad\.env.example') (Join-Path $dir '.env.example')
        Copy-Item (Join-Path $script:Fx 'bad\.env') (Join-Path $dir '.env')
        $target = Join-Path $dir '.env'
        $before = [IO.File]::ReadAllText($target)
        $rep = Get-EnvReport (Join-Path $dir '.env.example') $target
        $bak = Add-MissingKeys $target $rep
        Test-Path -LiteralPath $bak | Should -BeTrue
        [IO.File]::ReadAllText($bak) | Should -Be $before
        $after = [IO.File]::ReadAllText($target)
        $after | Should -Match '(?m)^DB_URL=\r?$'
        $after | Should -Match '(?m)^OPTIONAL=\r?$'
        $after.StartsWith($before) | Should -BeTrue
        $rep2 = Get-EnvReport (Join-Path $dir '.env.example') $target
        @($rep2.Missing).Count | Should -Be 0
    }
    It '.env bo''lmasa yangi fayl yaratadi, zaxirasiz' {
        $dir = Join-Path $TestDrive 'proj2'; New-Item -ItemType Directory -Path $dir | Out-Null
        Copy-Item (Join-Path $script:Fx 'ok\.env.example') (Join-Path $dir '.env.example')
        $target = Join-Path $dir '.env'
        $rep = Get-EnvReport (Join-Path $dir '.env.example') $target
        (Add-MissingKeys $target $rep) | Should -Be ''
        Test-Path -LiteralPath $target | Should -BeTrue
    }
}
