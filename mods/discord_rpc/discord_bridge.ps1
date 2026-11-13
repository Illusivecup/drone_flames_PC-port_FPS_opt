<#
Discord Rich Presence PowerShell Bridge for DroneFlames PC Port
Author: @good_boy_irl & @CryptoAngelazaz
#>

param(
    [Parameter(Mandatory=$true)][string]$StatePath,
    [Parameter(Mandatory=$false)][int]$ParentPid = 0
)

$clientId = "1566515978806759500"

function Test-ParentAlive([int]$pidToCheck) {
    if ($pidToCheck -le 0) { return $true }
    try {
        $p = [System.Diagnostics.Process]::GetProcessById($pidToCheck)
        return (-not $p.HasExited)
    } catch {
        return $false
    }
}

function Connect-DiscordPipe([string]$idToUse) {
    if ([string]::IsNullOrWhiteSpace($idToUse)) { $idToUse = $clientId }
    for ($i = 0; $i -lt 10; $i++) {
        $pipeName = "discord-ipc-$i"
        try {
            $pipe = New-Object System.IO.Pipes.NamedPipeClientStream('.', $pipeName, [System.IO.Pipes.PipeDirection]::InOut)
            $pipe.Connect(500)
            $pipe.ReadTimeout = 2000
            $pipe.WriteTimeout = 2000
            
            # Handshake
            $handshakeJson = "{`"v`":1,`"client_id`":`"$idToUse`"}"
            $handshakeBytes = [System.Text.Encoding]::UTF8.GetBytes($handshakeJson)
            $header = [System.BitConverter]::GetBytes([int32]0) + [System.BitConverter]::GetBytes([int32]$handshakeBytes.Length)
            $pipe.Write($header, 0, 8)
            $pipe.Write($handshakeBytes, 0, $handshakeBytes.Length)
            $pipe.Flush()

            $respHeader = New-Object byte[] 8
            $read = $pipe.Read($respHeader, 0, 8)
            if ($read -eq 8) {
                $respLen = [System.BitConverter]::ToInt32($respHeader, 4)
                $respBuf = New-Object byte[] $respLen
                $pipe.Read($respBuf, 0, $respLen) | Out-Null
                return $pipe
            }
            $pipe.Close()
        } catch {
            # continue
        }
    }
    return $null
}

function Send-Activity($pipe, $activityObj) {
    $actCmd = @{
        cmd = "SET_ACTIVITY"
        args = @{
            pid = [System.Diagnostics.Process]::GetCurrentProcess().Id
            activity = $activityObj
        }
        nonce = [string]([DateTime]::UtcNow.Ticks)
    }
    $jsonStr = $actCmd | ConvertTo-Json -Depth 6 -Compress
    $jsonBytes = [System.Text.Encoding]::UTF8.GetBytes($jsonStr)
    $header = [System.BitConverter]::GetBytes([int32]1) + [System.BitConverter]::GetBytes([int32]$jsonBytes.Length)
    $pipe.Write($header, 0, 8)
    $pipe.Write($jsonBytes, 0, $jsonBytes.Length)
    $pipe.Flush()

    $respHeader = New-Object byte[] 8
    try {
        $read = $pipe.Read($respHeader, 0, 8)
        if ($read -eq 8) {
            $respLen = [System.BitConverter]::ToInt32($respHeader, 4)
            $respBuf = New-Object byte[] $respLen
            $pipe.Read($respBuf, 0, $respLen) | Out-Null
        }
    } catch {
        # timeout or disconnect
    }
}

$pipe = $null
$lastStateRaw = ""

while ($true) {
    if ($ParentPid -gt 0 -and (-not (Test-ParentAlive $ParentPid))) {
        if ($pipe -ne $null) {
            try { Send-Activity $pipe $null; $pipe.Close() } catch {}
        }
        exit 0
    }

    if (-not (Test-Path $StatePath)) {
        Start-Sleep -Seconds 1
        continue
    }

    $stateRaw = ""
    try {
        $stateRaw = [System.IO.File]::ReadAllText($StatePath, [System.Text.Encoding]::UTF8).Trim()
    } catch {
        Start-Sleep -Seconds 1
        continue
    }

    if ([string]::IsNullOrWhiteSpace($stateRaw)) {
        Start-Sleep -Seconds 1
        continue
    }

    $stateData = $null
    try {
        $stateData = $stateRaw | ConvertFrom-Json
    } catch {
        Start-Sleep -Seconds 1
        continue
    }

    if ($stateData.shutdown -eq $true) {
        if ($pipe -ne $null) {
            try { Send-Activity $pipe $null; $pipe.Close() } catch {}
        }
        exit 0
    }

    if ($pipe -eq $null) {
        $curId = if ($stateData.client_id) { [string]$stateData.client_id } else { $clientId }
        $pipe = Connect-DiscordPipe $curId
        if ($pipe -eq $null) {
            Start-Sleep -Seconds 3
            continue
        }
        $lastStateRaw = ""
    }

    if ($stateRaw -ne $lastStateRaw) {
        $act = @{}
        if ($stateData.details) { $act["details"] = [string]$stateData.details }
        if ($stateData.state) { $act["state"] = [string]$stateData.state }
        if ($stateData.timestamps) { $act["timestamps"] = $stateData.timestamps }
        if ($stateData.assets) { $act["assets"] = $stateData.assets }
        if ($stateData.buttons) {
            $bList = New-Object System.Collections.ArrayList
            foreach ($b in $stateData.buttons) { [void]$bList.Add($b) }
            $act["buttons"] = $bList
        }

        try {
            Send-Activity $pipe $act
            $lastStateRaw = $stateRaw
        } catch {
            try { $pipe.Close() } catch {}
            $pipe = $null
            Start-Sleep -Seconds 2
            continue
        }
    }

    Start-Sleep -Seconds 1
}
