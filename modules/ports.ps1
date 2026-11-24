# ======================================================================
#  modules\ports.ps1 - Port va Lokal Servis menejeri (mantiq)
#  UI qobig'i va UZ/EN matnlar: modules\ports.bat (LANG_UZ / LANG_EN)
#  Chiqish kodlari: 0 = normal, 1 = xato, 20 = administrator bilan qayta ishga tushirish
# ======================================================================
#requires -Version 5.1
[CmdletBinding()]
param([switch]$NoRun)   # testlar uchun: funksiyalarni dot-source qilish, kirish nuqtasini ishga tushirmaslik
$ErrorActionPreference = 'Stop'

$script:TkMod = 'ports'
. (Join-Path (Split-Path -Parent $PSScriptRoot) 'lib\core.ps1')

# --- Sozlamalar ----------------------------------------------------------------
$script:DefaultWatch = @(
    [pscustomobject]@{ Port = 3000; Name = 'Node / React' },
    [pscustomobject]@{ Port = 5173; Name = 'Vite' },
    [pscustomobject]@{ Port = 5432; Name = 'PostgreSQL' },
    [pscustomobject]@{ Port = 6379; Name = 'Redis' },
    [pscustomobject]@{ Port = 8000; Name = 'Django / FastAPI' },
    [pscustomobject]@{ Port = 8080; Name = 'HTTP (alt)' }
)

# Hech qachon to'xtatilmaydi (kichik harf, kengaytmasiz)
$script:ProtectedNames = @(
    'system', 'idle', 'system idle process', 'registry', 'memcompression', 'memory compression',
    'smss', 'csrss', 'wininit', 'services', 'lsass', 'lsaiso', 'winlogon',
    'svchost', 'dwm', 'fontdrvhost', 'trustedinstaller', 'secure system'
)

# Qo'shimcha ehtiyot: port raqamini yozib tasdiqlash talab qilinadi
$script:WarnNames = @(
    'explorer', 'com.docker.backend', 'docker desktop', 'vpnkit', 'wslrelay', 'wslhost',
    'wslservice', 'vmmem', 'vmmemwsl', 'windowsterminal',
    'chrome', 'msedge', 'firefox', 'brave', 'code', 'devenv',
    'idea64', 'pycharm64', 'webstorm64', 'rider64'
)

# Hamma interfeysda ochiq bo'lsa ogohlantiriladigan baza portlari
$script:DbPorts = @(1433, 3306, 5432, 6379, 9200, 27017)

# --- Yordamchilar ----------------------------------------------------------------
function ConvertTo-TkPort([string]$Text) {
    if ($null -eq $Text) { return $null }
    $t = $Text.Trim()
    if ($t -notmatch '^[0-9]{1,5}\z') { return $null }
    $n = [int]$t
    if ($n -lt 1 -or $n -gt 65535) { return $null }
    return $n
}

# Standart ro'yxat + %LOCALAPPDATA%\VohidToolkit\ports.txt  (qator: PORT=Nom, # izoh)
function Get-WatchList {
    $list = New-Object System.Collections.ArrayList
    foreach ($d in $script:DefaultWatch) { [void]$list.Add($d) }

    $file = Join-Path $env:LOCALAPPDATA 'VohidToolkit\ports.txt'
    if (Test-Path -LiteralPath $file) {
        foreach ($line in @(Get-Content -LiteralPath $file -ErrorAction SilentlyContinue)) {
            $t = ([string]$line).Trim()
            if ($t -eq '' -or $t.StartsWith('#')) { continue }
            $parts = $t -split '=', 2
            $n = ConvertTo-TkPort $parts[0]
            if ($null -eq $n -or $list.Count -ge 20) {
                Write-TkLog 'WARN' ('ports.txt skipped line: ' + $parts[0])
                continue
            }
            $label = ''
            if ($parts.Count -gt 1) { $label = $parts[1].Trim() }
            $found = $null
            foreach ($x in $list) { if ($x.Port -eq $n) { $found = $x } }
            if ($null -ne $found) {
                if ($label -ne '') { $found.Name = $label }
            } else {
                [void]$list.Add([pscustomobject]@{ Port = $n; Name = $label })
            }
        }
    }
    return @($list | Sort-Object Port)
}

# port -> @{ Port; Pids[]; Addrs[] }   (faqat LISTEN, IPv4 + IPv6)
function Get-ListenerIndex {
    $idx = @{}
    $rows = @(Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue)
    foreach ($r in $rows) {
        $p = [int]$r.LocalPort
        if (-not $idx.ContainsKey($p)) {
            $idx[$p] = [pscustomobject]@{ Port = $p; Pids = @(); Addrs = @() }
        }
        $e = $idx[$p]
        $op = [int]$r.OwningProcess
        if ($e.Pids -notcontains $op) { $e.Pids += $op }
        $ad = [string]$r.LocalAddress
        if ($e.Addrs -notcontains $ad) { $e.Addrs += $ad }
    }
    return $idx
}

# ProcessId -> servis nomlari (ishlayotgan servislar)
function Get-ServiceIndex {
    $idx = @{}
    $svcs = @(Get-CimInstance -ClassName Win32_Service -Filter "State = 'Running'" -ErrorAction SilentlyContinue)
    foreach ($s in $svcs) {
        $k = [int]$s.ProcessId
        if ($k -le 0) { continue }
        if (-not $idx.ContainsKey($k)) { $idx[$k] = @() }
        $idx[$k] += [string]$s.Name
    }
    return $idx
}

function Get-ProcInfo([int]$ProcId) {
    $cim = Get-CimInstance -ClassName Win32_Process -Filter "ProcessId = $ProcId" -ErrorAction SilentlyContinue
    if ($null -eq $cim) { return $null }
    $owner = ''
    try {
        $o = Invoke-CimMethod -InputObject $cim -MethodName GetOwner -ErrorAction Stop
        if ($o.ReturnValue -eq 0) { $owner = '{0}\{1}' -f $o.Domain, $o.User }
    } catch { }
    return [pscustomobject]@{
        ProcId   = $ProcId
        Name     = [System.IO.Path]::GetFileNameWithoutExtension([string]$cim.Name)
        Path     = [string]$cim.ExecutablePath
        Cmd      = [string]$cim.CommandLine
        Start    = $cim.CreationDate
        Owner    = $owner
        ParentId = [int]$cim.ParentProcessId
    }
}

# Toolkit o'zi va uning ota-ona zanjiri (terminal, cmd) - hech qachon to'xtatilmaydi
function Get-SelfChain {
    $chain = @()
    $cur = [int]$PID
    for ($i = 0; $i -lt 12 -and $cur -gt 0; $i++) {
        if ($chain -contains $cur) { break }
        $chain += $cur
        $c = Get-CimInstance -ClassName Win32_Process -Filter "ProcessId = $cur" -ErrorAction SilentlyContinue
        if ($null -eq $c) { break }
        $cur = [int]$c.ParentProcessId
    }
    return $chain
}
$script:SelfChain = @(Get-SelfChain)

# Jarayon (yoki 4 darajagacha ota-onasi) Windows servisini ishga tushirganmi?
# Qaytaradi: $null | @{ Shared = $true } | @{ Names = [..]; HostPid = n }
function Resolve-ServiceHost($Info, $SvcIdx) {
    $cur = $Info
    for ($depth = 0; $depth -lt 4 -and $null -ne $cur; $depth++) {
        if ($SvcIdx.ContainsKey($cur.ProcId)) {
            if ($cur.Name -ieq 'svchost') { return @{ Shared = $true } }
            return @{ Names = @($SvcIdx[$cur.ProcId]); HostPid = $cur.ProcId }
        }
        if ($cur.ParentId -le 4) { break }
        $cur = Get-ProcInfo $cur.ParentId
    }
    return $null
}

# Sinf: PROTECTED | SERVICE | WARN | NORMAL
function Get-Classification($Info, $SvcHost) {
    $n = $Info.Name.ToLowerInvariant()
    if ($n -eq 'svchost' -or ($null -ne $SvcHost -and $SvcHost.ContainsKey('Shared'))) {
        return @{ Class = 'PROTECTED'; Reason = 'SHARED' }
    }
    if ($Info.ProcId -le 4 -or $script:ProtectedNames -contains $n) {
        return @{ Class = 'PROTECTED'; Reason = 'SYSTEM' }
    }
    if ($script:SelfChain -contains $Info.ProcId) {
        return @{ Class = 'PROTECTED'; Reason = 'SELF' }
    }
    if ($null -ne $SvcHost -and $SvcHost.ContainsKey('Names')) {
        return @{ Class = 'SERVICE'; Reason = ''; Services = @($SvcHost.Names); HostPid = $SvcHost.HostPid }
    }
    if ($script:WarnNames -contains $n) {
        return @{ Class = 'WARN'; Reason = 'WARN' }
    }
    return @{ Class = 'NORMAL'; Reason = '' }
}

function Test-NeedsAdmin($Info, $Cls) {
    if (Test-TkAdmin) { return $false }
    if ($Cls.Class -eq 'SERVICE') { return $true }
    $me = [Security.Principal.WindowsIdentity]::GetCurrent().Name
    if ($Info.Owner -and ($Info.Owner -ine $me)) { return $true }
    return $false
}

# Port hali ham shu PID tomonidan tinglanayotganini va jarayon o'zgarmaganini tekshiradi
function Test-SameTarget([int]$Port, $Info) {
    $c = @(Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue |
           Where-Object { $_.OwningProcess -eq $Info.ProcId })
    if ($c.Count -eq 0) { return $false }
    $now = Get-CimInstance -ClassName Win32_Process -Filter "ProcessId = $($Info.ProcId)" -ErrorAction SilentlyContinue
    if ($null -eq $now) { return $false }
    return ($now.CreationDate -eq $Info.Start)
}

# Port bo'shashini kutadi (~4 s). Qaytaradi: hali tinglayotgan PID lar (bo'sh = bo'sh port)
function Wait-PortFree([int]$Port) {
    $c = @()
    for ($i = 0; $i -lt 10; $i++) {
        $c = @(Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue)
        if ($c.Count -eq 0) { return @() }
        Start-Sleep -Milliseconds 400
    }
    return @($c | Select-Object -ExpandProperty OwningProcess -Unique)
}

# --- Ko'rsatish ----------------------------------------------------------------------
function Show-Dashboard($Watch, $Index) {
    $c = $script:Col
    Show-TkHeader (Get-TkText 'P_TITLE')

    $names = @{}
    $need = @()
    foreach ($w in $Watch) {
        if ($Index.ContainsKey([int]$w.Port)) { $need += $Index[[int]$w.Port].Pids }
    }
    $need = @($need | Select-Object -Unique)
    if ($need.Count -gt 0) {
        foreach ($gp in @(Get-Process -Id $need -ErrorAction SilentlyContinue)) {
            $names[[int]$gp.Id] = [string]$gp.ProcessName
        }
    }

    $wP = 6; $wN = 16; $wS = 7; $wI = 7; $wR = 17; $wB = 15
    $hdr = '  ' + (Format-Fit (Get-TkText 'P_COL_PORT') $wP) + '  ' + (Format-Fit (Get-TkText 'P_COL_NAME') $wN) +
           '  ' + (Format-Fit (Get-TkText 'P_COL_STATE') $wS) + '  ' + (Format-Fit (Get-TkText 'P_COL_PID') $wI) +
           '  ' + (Format-Fit (Get-TkText 'P_COL_PROC') $wR) + '  ' + (Get-TkText 'P_COL_BIND')
    Write-Host ($c.Dim + $hdr + $c.Reset)
    Write-Host ($c.Dim + '  ' + ('-' * 70) + $c.Reset)

    $busy = 0
    $anyExposed = $false
    foreach ($w in $Watch) {
        $e = $null
        if ($Index.ContainsKey([int]$w.Port)) { $e = $Index[[int]$w.Port] }

        $stateText = Get-TkText 'P_FREE'; $stateCol = $c.Green
        $pidText = '-'; $pname = '-'; $bind = '-'; $flag = ''
        if ($null -ne $e) {
            $busy++
            $stateText = Get-TkText 'P_BUSY'; $stateCol = $c.Yellow
            $pidText = ($e.Pids -join ',')
            $first = [int]$e.Pids[0]
            $pname = ''
            if ($names.ContainsKey($first)) { $pname = $names[$first] }
            if ($e.Pids.Count -gt 1) { $pname = $pname + ' +' + ($e.Pids.Count - 1) }
            $bind = (@($e.Addrs | Select-Object -First 2) -join ',')
            $open = ($e.Addrs -contains '0.0.0.0') -or ($e.Addrs -contains '::')
            if ($open -and ($script:DbPorts -contains [int]$w.Port)) {
                $flag = ' ' + $c.Red + '!' + $c.Reset
                $anyExposed = $true
            }
        }
        Write-Host ('  ' + (Format-Fit ([string]$w.Port) $wP) + '  ' + (Format-Fit ([string]$w.Name) $wN) + '  ' +
                    $stateCol + (Format-Fit $stateText $wS) + $c.Reset + '  ' + (Format-Fit $pidText $wI) + '  ' +
                    (Format-Fit $pname $wR) + '  ' + $bind + $flag)
    }

    Write-Host ''
    Write-Host ('  ' + $c.Dim + ((Get-TkText 'P_SUMMARY') -f $busy, @($Watch).Count) + $c.Reset)
    if ($anyExposed) { Write-Host ('  ' + $c.Red + '!' + $c.Reset + ' ' + (Get-TkText 'P_EXPOSED')) }
    Write-Host ''
    Write-Host ('  ' + $c.Dim + ('-' * 70) + $c.Reset)
    Write-Host ('  ' + (Get-TkText 'P_PROMPT'))
    Write-Host ('  ' + $c.Dim + (Get-TkText 'P_HINT') + $c.Reset)
    Write-Host ''
}

function Show-Detail([int]$Port, $Info, $Cls, $Addrs) {
    $c = $script:Col
    $clsCol = $c.Green
    if ($Cls.Class -eq 'PROTECTED') { $clsCol = $c.Red }
    elseif ($Cls.Class -eq 'WARN') { $clsCol = $c.Yellow }
    elseif ($Cls.Class -eq 'SERVICE') { $clsCol = $c.Cyan }

    $cmd = $Info.Cmd
    if ($cmd.Length -gt 90) { $cmd = $cmd.Substring(0, 89) + '~' }
    $started = '-'
    if ($Info.Start -is [datetime]) { $started = $Info.Start.ToString('yyyy-MM-dd HH:mm:ss') }
    $svcText = '-'
    if ($Cls.Class -eq 'SERVICE') { $svcText = ($Cls.Services -join ', ') }

    $rows = @(
        @((Get-TkText 'P_D_PORT'),  [string]$Port),
        @((Get-TkText 'P_D_PROC'),  ('{0}   PID {1}' -f $Info.Name, $Info.ProcId)),
        @((Get-TkText 'P_D_PATH'),  $(if ($Info.Path) { $Info.Path } else { '-' })),
        @((Get-TkText 'P_D_CMD'),   $(if ($cmd) { $cmd } else { '-' })),
        @((Get-TkText 'P_D_START'), $started),
        @((Get-TkText 'P_D_OWNER'), $(if ($Info.Owner) { $Info.Owner } else { '-' })),
        @((Get-TkText 'P_D_SVC'),   $svcText),
        @((Get-TkText 'P_D_BIND'),  (@($Addrs) -join ', '))
    )
    Write-Host ''
    Write-Host ('  ' + $c.Cyan + ('-' * 70) + $c.Reset)
    foreach ($r in $rows) {
        Write-Host ('    ' + $c.Dim + (Format-Fit $r[0] 11) + $c.Reset + ': ' + $r[1])
    }
    Write-Host ('    ' + $c.Dim + (Format-Fit (Get-TkText 'P_D_CLASS') 11) + $c.Reset + ': ' +
                $clsCol + (Get-TkText ('P_CLS_' + $Cls.Class)) + $c.Reset)
    Write-Host ('  ' + $c.Cyan + ('-' * 70) + $c.Reset)
}

# --- Amallar -------------------------------------------------------------------------
function Request-AdminRelaunch {
    Write-TkWarn (Get-TkText 'NEEDADMIN')
    if (Confirm-TkYesNo (Get-TkText 'RELAUNCH_ASK')) { return 'RELAUNCH' }
    Write-TkInfo (Get-TkText 'CANCELLED')
    return 'DONE'
}

function Invoke-StopService([int]$Port, $Info, $Cls) {
    $names = ($Cls.Services -join ', ')
    if (-not (Confirm-TkYesNo ((Get-TkText 'P_ASK_SVC') -f $names))) {
        Write-TkInfo (Get-TkText 'CANCELLED')
        return 'DONE'
    }
    foreach ($sn in $Cls.Services) {
        Write-TkLog 'ACTION' ("stop-service name=$sn port=$Port hostpid=$($Cls.HostPid)")
        try {
            $s = Get-Service -Name $sn -ErrorAction Stop
            if ($s.Status -ne 'Stopped') {
                Stop-Service -InputObject $s -ErrorAction Stop
                $s.WaitForStatus('Stopped', [TimeSpan]::FromSeconds(20))
            }
            Write-TkOk ((Get-TkText 'P_SVC_OK') + ' ' + $sn)
        } catch {
            $msg = $_.Exception.Message
            Write-TkErr ((Get-TkText 'P_SVC_FAIL') + ' ' + $sn + ' - ' + $msg)
            if ($msg -match 'dependent') { Write-TkInfo (Get-TkText 'P_SVC_HINT') }
        }
    }
    $left = @(Wait-PortFree $Port)
    if ($left.Count -eq 0) { Write-TkOk ((Get-TkText 'P_PORT_FREE') + ' ' + $Port) }
    else { Write-TkWarn ((Get-TkText 'P_STILL_BUSY') + ' ' + ($left -join ', ')) }
    return 'DONE'
}

function Invoke-StopProcess([int]$Port, $Info, $Cls) {
    if ($Cls.Class -eq 'WARN') {
        Write-TkWarn (Get-TkText 'P_R_WARN')
        $typed = Read-TkLine ((Get-TkText 'P_TYPE_CONFIRM') -f $Port)
        if ($null -eq $typed -or $typed.Trim() -ne [string]$Port) {
            Write-TkErr (Get-TkText 'P_MISMATCH')
            return 'DONE'
        }
    } else {
        if (-not (Confirm-TkYesNo ((Get-TkText 'P_ASK_KILL') -f $Info.Name, $Info.ProcId, $Port))) {
            Write-TkInfo (Get-TkText 'CANCELLED')
            return 'DONE'
        }
    }

    # Tasdiq bilan o'chirish orasida holat o'zgargan bo'lishi mumkin (PID qayta ishlatilishi)
    if (-not (Test-SameTarget $Port $Info)) {
        Write-TkErr (Get-TkText 'P_CHANGED')
        return 'DONE'
    }

    Write-TkLog 'ACTION' ("stop-process port=$Port pid=$($Info.ProcId) name=$($Info.Name) class=$($Cls.Class)")

    # 1) Oynali ilova bo'lsa avval muloyim yopishga urinish
    $gp = Get-Process -Id $Info.ProcId -ErrorAction SilentlyContinue
    $closed = $false
    if ($null -ne $gp -and $gp.MainWindowHandle -ne [IntPtr]::Zero) {
        Write-TkInfo (Get-TkText 'P_GRACEFUL')
        [void]$gp.CloseMainWindow()
        $closed = $gp.WaitForExit(4000)
        if (-not $closed) {
            if (-not (Confirm-TkYesNo (Get-TkText 'P_ASK_FORCE'))) {
                Write-TkInfo (Get-TkText 'CANCELLED')
                return 'DONE'
            }
        }
    }

    # 2) Majburiy to'xtatish
    if (-not $closed) {
        try {
            Stop-Process -Id $Info.ProcId -Force -ErrorAction Stop
        } catch {
            $msg = $_.Exception.Message
            Write-TkErr ((Get-TkText 'P_KILL_FAIL') + ' ' + $Info.Name + ' (PID ' + $Info.ProcId + ') - ' + $msg)
            if (-not (Test-TkAdmin) -and $msg -match 'denied') {
                Write-TkInfo (Get-TkText 'P_DENIED')
                return (Request-AdminRelaunch)
            }
            return 'DONE'
        }
    }

    # 3) Natijani tekshirish
    $left = @(Wait-PortFree $Port)
    if ($left.Count -eq 0) {
        Write-TkOk ((Get-TkText 'P_STOPPED_OK') + ' ' + $Port)
    } else {
        $who = @()
        foreach ($lp in $left) {
            $gp2 = Get-Process -Id $lp -ErrorAction SilentlyContinue
            if ($null -ne $gp2) { $who += ('{0} (PID {1})' -f $gp2.ProcessName, $lp) } else { $who += ('PID ' + $lp) }
        }
        Write-TkWarn ((Get-TkText 'P_STILL_BUSY') + ' ' + ($who -join ', '))
    }
    return 'DONE'
}

function Invoke-OneProcess([int]$Port, [int]$ProcId, $Addrs, $SvcIdx) {
    $info = Get-ProcInfo $ProcId
    if ($null -eq $info) {
        Write-TkWarn ((Get-TkText 'P_NOINFO') + ' PID ' + $ProcId)
        return 'DONE'
    }
    $svcHost = Resolve-ServiceHost $info $SvcIdx
    $cls = Get-Classification $info $svcHost
    Show-Detail $Port $info $cls $Addrs
    Write-TkLog 'INFO' ("inspect port=$Port pid=$ProcId name=$($info.Name) class=$($cls.Class)")

    if ($cls.Class -eq 'PROTECTED') {
        Write-TkErr ((Get-TkText 'P_REFUSED') + ' ' + (Get-TkText ('P_R_' + $cls.Reason)))
        return 'DONE'
    }
    if (Test-NeedsAdmin $info $cls) {
        return (Request-AdminRelaunch)
    }
    if ($cls.Class -eq 'SERVICE') { return (Invoke-StopService $Port $info $cls) }
    return (Invoke-StopProcess $Port $info $cls)
}

function Invoke-PortAction([int]$Port) {
    $idx = Get-ListenerIndex
    if (-not $idx.ContainsKey($Port)) {
        Write-TkInfo ((Get-TkText 'P_FREE_MSG') + ' ' + $Port)
        return 'DONE'
    }
    $entry = $idx[$Port]
    $svcIdx = Get-ServiceIndex
    if ($entry.Pids.Count -gt 1) { Write-TkWarn (Get-TkText 'P_MULTI') }
    foreach ($procId in $entry.Pids) {
        $r = @(Invoke-OneProcess $Port ([int]$procId) $entry.Addrs $svcIdx) | Select-Object -Last 1
        if ($r -eq 'RELAUNCH') { return 'RELAUNCH' }
    }
    return 'DONE'
}

# --- Asosiy tsikl --------------------------------------------------------------------------
function Start-PortsModule {
    $watch = Get-WatchList
    while ($true) {
        $idx = Get-ListenerIndex
        Show-Dashboard $watch $idx

        $raw = Read-TkLine '>>'
        if ($null -eq $raw) { return 0 }
        $s = ($raw -replace '[\s"]', '')
        if ($s -eq '' -or $s -ieq 'r') { continue }
        if ($s -eq '0' -or $s -ieq 'q') { return 0 }

        $port = ConvertTo-TkPort $s
        if ($null -eq $port) {
            Write-TkErr (Get-TkText 'P_BAD')
            Start-Sleep -Milliseconds 1500
            continue
        }
        $res = @(Invoke-PortAction $port) | Select-Object -Last 1
        if ($res -eq 'RELAUNCH') { return 20 }
        Wait-TkKey
    }
}

if ($NoRun) { return }

try {
    if (-not (Get-Command Get-NetTCPConnection -ErrorAction SilentlyContinue)) {
        Write-TkErr (Get-TkText 'P_NOCMDLET')
        exit 1
    }
    Write-TkLog 'INFO' 'module start'
    $code = [int](@(Start-PortsModule) | Select-Object -Last 1)
    Write-TkLog 'INFO' "module exit code=$code"
    exit $code
} catch {
    Write-TkErr ((Get-TkText 'P_FAIL') + ' ' + $_.Exception.Message)
    exit 1
}
