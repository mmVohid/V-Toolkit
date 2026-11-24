# End-to-end: TOOLKIT.bat ni haqiqiy cmd.exe orqali ishga tushirib, CLI va menyuni tekshirish
BeforeAll {
    $global:TkRoot = Split-Path -Parent $PSScriptRoot
    $global:TkBat  = Join-Path $global:TkRoot 'TOOLKIT.bat'
    $global:TkFx   = Join-Path $PSScriptRoot 'fixtures\env'
    $global:TkLogDir = Join-Path $env:LOCALAPPDATA 'VohidToolkit\logs'

    function Invoke-Tk([string]$ArgLine, [string]$InputText = '') {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = 'cmd.exe'
        $psi.Arguments = '/d /s /c ""' + $global:TkBat + '" ' + $ArgLine + '"'
        $psi.UseShellExecute = $false
        $psi.RedirectStandardInput = $true
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
        $psi.WorkingDirectory = $global:TkRoot
        $p = [System.Diagnostics.Process]::Start($psi)
        $p.StandardInput.Write($InputText)
        $p.StandardInput.Close()
        $so = $p.StandardOutput.ReadToEndAsync()
        $se = $p.StandardError.ReadToEndAsync()
        if (-not $p.WaitForExit(40000)) {
            & taskkill.exe /T /F /PID $p.Id 2>&1 | Out-Null
            [void]$so.Wait(5000); [void]$se.Wait(5000)
            $partial = ''
            if ($so.IsCompleted) { $partial += $so.Result }
            if ($se.IsCompleted) { $partial += $se.Result }
            return [pscustomobject]@{ Code = -999; Text = ('TIMEOUT. Partial output (last 3000 chars):' + [Environment]::NewLine + $partial.Substring([Math]::Max(0, $partial.Length - 3000))) }
        }
        [pscustomobject]@{ Code = $p.ExitCode; Text = ($so.Result + $se.Result) }
    }
}

Describe 'CLI' {
    It 'about --lang EN' {
        $r = Invoke-Tk 'about --lang EN --no-color'
        $r.Code | Should -Be 0
        $r.Text | Should -Match 'lightweight'
        $r.Text | Should -Match 'Log\s+:'
    }
    It 'about --lang UZ' {
        $r = Invoke-Tk 'about --lang UZ --no-color'
        $r.Code | Should -Be 0
        $r.Text | Should -Match 'Muallif'
    }
    It 'noma''lum buyruq: kod 1' {
        $r = Invoke-Tk 'bogus --lang EN --no-color'
        $r.Code | Should -Be 1
        $r.Text | Should -Match 'Unknown command'
    }
}

Describe 'Menyu (stdin orqali)' {
    It 'noto''g''ri buyruqdan keyin 0 bilan chiqadi' {
        $r = Invoke-Tk '--lang EN --no-color' "99`r`n0`r`n"
        $r.Code | Should -Be 0 -Because $r.Text
        $r.Text | Should -Match 'VOHID TOOLKIT'
        $r.Text | Should -Match '\[11\]'
        $r.Text | Should -Match 'Invalid command'
        $r.Text | Should -Match 'Admin: (ON|OFF)'
    }
    It 'kirish tugasa (EOF) cheksiz tsiklga tushmaydi' {
        $r = Invoke-Tk '--lang EN --no-color' ''
        $r.Code | Should -Not -Be -999 -Because $r.Text
    }
    It 'til tanlash lang.cfg ga yoziladi' {
        $r = Invoke-Tk '--no-color' "L`r`n2`r`n0`r`n"
        $r.Code | Should -Be 0 -Because $r.Text
        (Get-Content -LiteralPath (Join-Path $env:LOCALAPPDATA 'VohidToolkit\lang.cfg') -TotalCount 1).Trim() | Should -Be 'EN'
    }
}

Describe '.env CLI (--ci)' {
    It 'toza juftlik: kod 0' {
        $r = Invoke-Tk ('env "' + (Join-Path $global:TkFx 'ok') + '" --ci --lang EN')
        $r.Code | Should -Be 0
        $r.Text | Should -Match 'All good'
    }
    It 'muammo bor: kod 1, kalitlar ko''rinadi' {
        $r = Invoke-Tk ('env "' + (Join-Path $global:TkFx 'bad') + '" --ci --lang EN')
        $r.Code | Should -Be 1
        foreach ($k in 'MISSING', 'EMPTY', 'EXTRA', 'DUPLICATE', 'DB_URL', 'OPTIONAL', 'PORT', 'LEGACY', 'JWT_SECRET') {
            $r.Text | Should -Match $k
        }
    }
    It 'namuna yo''q: kod 2' {
        $r = Invoke-Tk ('env "' + (Join-Path $global:TkFx 'noexample') + '" --ci --lang EN')
        $r.Code | Should -Be 2
    }
    It 'papka yo''q: kod 2' {
        $r = Invoke-Tk ('env "' + (Join-Path $global:TkFx 'does-not-exist') + '" --ci --lang EN')
        $r.Code | Should -Be 2
    }
    It 'qiymatlar na chiqishda, na logda uchramaydi' {
        $bad = Invoke-Tk ('env "' + (Join-Path $global:TkFx 'bad') + '" --ci --lang EN')
        $ok  = Invoke-Tk ('env "' + (Join-Path $global:TkFx 'ok') + '" --ci --lang EN')
        $secrets = 'TOP_SECRET_VALUE_999', 'again_SECRET_2', 'SUPERSECRET_TOKEN_123', 'postgres://u:p@h/db'
        foreach ($s in $secrets) {
            $bad.Text | Should -Not -Match ([regex]::Escape($s))
            $ok.Text  | Should -Not -Match ([regex]::Escape($s))
        }
        $logs = @(Get-ChildItem -LiteralPath $global:TkLogDir -Filter 'toolkit-*.log' -ErrorAction SilentlyContinue)
        $logs.Count | Should -BeGreaterThan 0
        $all = ($logs | ForEach-Object { [IO.File]::ReadAllText($_.FullName) }) -join "`n"
        foreach ($s in $secrets) { $all | Should -Not -Match ([regex]::Escape($s)) }
        $all | Should -Match 'check example=\.env\.example target=\.env'
    }
}

Describe 'ports CLI' {
    BeforeAll {
        $global:PortsTxt = Join-Path $env:LOCALAPPDATA 'VohidToolkit\ports.txt'
        $global:PortsBak = $null
        if (Test-Path -LiteralPath $global:PortsTxt) { $global:PortsBak = [IO.File]::ReadAllText($global:PortsTxt) }
        $global:E2EPort = Get-Random -Minimum 41000 -Maximum 45000
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $global:PortsTxt) | Out-Null
        [IO.File]::WriteAllText($global:PortsTxt, "# e2e`r`n$($global:E2EPort)=E2E-Test`r`n9999999=bad`r`n")
        $cmd = '$l=[Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback,' + $global:E2EPort + ');$l.Start();Start-Sleep -Seconds 120'
        $global:Listener = Start-Process -FilePath 'powershell.exe' -ArgumentList '-NoProfile', '-Command', $cmd -PassThru -WindowStyle Hidden
        Start-Sleep -Seconds 3
    }
    AfterAll {
        try { if (-not $global:Listener.HasExited) { $global:Listener.Kill() } } catch { }
        if ($null -ne $global:PortsBak) { [IO.File]::WriteAllText($global:PortsTxt, $global:PortsBak) }
        else { Remove-Item -LiteralPath $global:PortsTxt -Force -ErrorAction SilentlyContinue }
    }

    It 'dashboard chiqadi, sinov porti LISTEN, noto''g''ri qator o''tkazib yuboriladi' {
        $r = Invoke-Tk 'ports --lang EN --no-color'
        $r.Code | Should -Be 0
        $r.Text | Should -Match 'PORTS AND LOCAL SERVICES'
        $row = ($r.Text -split "`r?`n" | Where-Object { $_ -match 'E2E-Test' } | Select-Object -First 1)
        $row | Should -Not -BeNullOrEmpty
        $row | Should -Match 'LISTEN'
        $r.Text | Should -Not -Match '9999999'
    }
    It 'dashboard UZ matnlari' {
        $r = Invoke-Tk 'ports --lang UZ --no-color'
        $r.Code | Should -Be 0
        $r.Text | Should -Match 'PORTLAR VA LOKAL SERVISLAR'
    }
    It 'menyu orqali: noto''g''ri port rad etiladi, keyin 0' {
        $r = Invoke-Tk '--lang EN --no-color' "10`r`n99999`r`n0`r`n0`r`n"
        $r.Code | Should -Be 0 -Because $r.Text
        $r.Text | Should -Match 'whole number from 1 to 65535'
    }
}

Describe 'Log' {
    It 'start yozuvi bor' {
        $null = Invoke-Tk 'about --lang EN --no-color'
        $logs = @(Get-ChildItem -LiteralPath $global:TkLogDir -Filter 'toolkit-*.log')
        $all = ($logs | ForEach-Object { [IO.File]::ReadAllText($_.FullName) }) -join "`n"
        $all | Should -Match '\[INFO\] \[main\] start v2\.1\.0'
    }
}
