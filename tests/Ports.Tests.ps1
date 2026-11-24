# Port menejeri mantig'i (modules\ports.ps1): validatsiya, sinflash, himoya, o'chirish (mock bilan va haqiqiy)
BeforeAll {
    $root = Split-Path -Parent $PSScriptRoot
    . (Join-Path $root 'modules\ports.ps1') -NoRun

    function Start-TestListener([int]$Port) {
        $cmd = '$l=[Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback,' + $Port + ');$l.Start();Start-Sleep -Seconds 120'
        $p = Start-Process -FilePath 'powershell.exe' -ArgumentList '-NoProfile', '-Command', $cmd -PassThru -WindowStyle Hidden
        for ($i = 0; $i -lt 40; $i++) {
            $idx = Get-ListenerIndex
            if ($idx.ContainsKey($Port)) { return $p }
            Start-Sleep -Milliseconds 250
        }
        try { $p.Kill() } catch { }
        throw "listener did not start on $Port"
    }
}

Describe 'ConvertTo-TkPort' {
    It 'qabul qiladi: <Text> -> <Expected>' -ForEach @(
        @{ Text = '1';       Expected = 1 }
        @{ Text = '80';      Expected = 80 }
        @{ Text = '08080';   Expected = 8080 }
        @{ Text = ' 3000 ';  Expected = 3000 }
        @{ Text = '65535';   Expected = 65535 }
    ) {
        ConvertTo-TkPort $Text | Should -Be $Expected
    }
    It 'rad etadi: "<Text>"' -ForEach @(
        @{ Text = '' }, @{ Text = '0' }, @{ Text = '00000' }, @{ Text = '65536' }, @{ Text = '99999' },
        @{ Text = '123456' }, @{ Text = '-1' }, @{ Text = 'abc' }, @{ Text = '80a' }, @{ Text = '8 080' }, @{ Text = '1e3' }
    ) {
        ConvertTo-TkPort $Text | Should -BeNullOrEmpty
    }
}

Describe 'Get-Classification' {
    BeforeAll {
        function New-Info([int]$ProcId, [string]$Name) {
            [pscustomobject]@{ ProcId = $ProcId; Name = $Name; Path = ''; Cmd = ''; Start = (Get-Date); Owner = ''; ParentId = 0 }
        }
    }
    It '<Name> (PID <ProcId>) -> <Class>/<Reason>' -ForEach @(
        @{ Name = 'svchost';  ProcId = 900;  Class = 'PROTECTED'; Reason = 'SHARED' }
        @{ Name = 'lsass';    ProcId = 700;  Class = 'PROTECTED'; Reason = 'SYSTEM' }
        @{ Name = 'csrss';    ProcId = 600;  Class = 'PROTECTED'; Reason = 'SYSTEM' }
        @{ Name = 'System';   ProcId = 4;    Class = 'PROTECTED'; Reason = 'SYSTEM' }
        @{ Name = 'anything'; ProcId = 0;    Class = 'PROTECTED'; Reason = 'SYSTEM' }
        @{ Name = 'chrome';   ProcId = 12345; Class = 'WARN';     Reason = 'WARN' }
        @{ Name = 'com.docker.backend'; ProcId = 12346; Class = 'WARN'; Reason = 'WARN' }
        @{ Name = 'node';     ProcId = 12347; Class = 'NORMAL';   Reason = '' }
    ) {
        $c = Get-Classification (New-Info $ProcId $Name) $null
        $c.Class  | Should -Be $Class
        $c.Reason | Should -Be $Reason
    }
    It 'Toolkit jarayoni va ota-onasi himoyalangan (SELF)' {
        $c = Get-Classification (New-Info $PID 'someapp') $null
        $c.Class | Should -Be 'PROTECTED'
        $c.Reason | Should -Be 'SELF'
    }
    It 'servis ishga tushirgan jarayon SERVICE' {
        $c = Get-Classification (New-Info 12348 'postgres') @{ Names = @('postgresql-x64-16'); HostPid = 12348 }
        $c.Class | Should -Be 'SERVICE'
        @($c.Services) | Should -Be @('postgresql-x64-16')
    }
    It 'umumiy servis hosti (Shared) himoyalangan' {
        $c = Get-Classification (New-Info 12349 'otherhost') @{ Shared = $true }
        $c.Class | Should -Be 'PROTECTED'
        $c.Reason | Should -Be 'SHARED'
    }
}

Describe 'Himoyalangan portlar hech qachon to''xtatilmaydi' {
    It 'tizim/servis jarayoni tinglayotgan port: Stop-Process va Stop-Service chaqirilmaydi' {
        $idx = Get-ListenerIndex
        $target = $null
        foreach ($p in 135, 445, 5985, 49664) { if ($idx.ContainsKey($p)) { $target = $p; break } }
        if ($null -eq $target) { Set-ItResult -Skipped -Because 'tizim porti topilmadi'; return }
        Mock Confirm-TkYesNo { $true }
        Mock Read-TkLine { [string]$target }
        Mock Stop-Process { }
        Mock Stop-Service { }
        $null = Invoke-PortAction $target 6>&1
        Should -Invoke Stop-Process -Times 0 -Exactly
        Should -Invoke Stop-Service -Times 0 -Exactly
    }
}

Describe 'Haqiqiy tinglovchini to''xtatish' {
    BeforeEach {
        $script:Port = Get-Random -Minimum 20000 -Maximum 40000
        $script:Child = Start-TestListener $script:Port
    }
    AfterEach {
        try { if ($script:Child -and -not $script:Child.HasExited) { $script:Child.Kill() } } catch { }
    }

    It 'Get-ListenerIndex portni va PID ni ko''radi' {
        $idx = Get-ListenerIndex
        $idx.ContainsKey($script:Port) | Should -BeTrue
        $idx[$script:Port].Pids | Should -Contain $script:Child.Id
    }

    It 'tasdiqlangach jarayon to''xtaydi va port bo''shaydi' {
        Mock Confirm-TkYesNo { $true }
        $null = Invoke-PortAction $script:Port 6>&1
        $script:Child.WaitForExit(8000) | Should -BeTrue
        (Get-ListenerIndex).ContainsKey($script:Port) | Should -BeFalse
    }

    It '"Yo''q" deyilsa jarayon tirik qoladi' {
        Mock Confirm-TkYesNo { $false }
        Mock Stop-Process { }
        $null = Invoke-PortAction $script:Port 6>&1
        Should -Invoke Stop-Process -Times 0 -Exactly
        $script:Child.HasExited | Should -BeFalse
    }

    It 'tasdiq bilan o''chirish orasida holat o''zgarsa (TOCTOU) hech narsa to''xtatilmaydi' {
        Mock Confirm-TkYesNo { $true }
        Mock Test-SameTarget { $false }
        Mock Stop-Process { }
        $null = Invoke-PortAction $script:Port 6>&1
        Should -Invoke Stop-Process -Times 0 -Exactly
        $script:Child.HasExited | Should -BeFalse
    }

    It 'bo''sh port: hech narsa qilinmaydi' {
        Mock Stop-Process { }
        $free = $script:Port + 1
        $null = Invoke-PortAction $free 6>&1
        Should -Invoke Stop-Process -Times 0 -Exactly
    }
}
