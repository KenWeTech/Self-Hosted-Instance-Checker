# ================================
# SELF-HOSTED INSTANCE CHECKER
# ================================

# --- USER SETTINGS (EDIT THIS SECTION) ---

$logToFile     = $false        # Set to $true to turn on logs / $false to turn off logs
$shortcutPath  = "$env:USERPROFILE\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup"
$homeAssistantIP = "10.0.0.2"  # Enter the IP address for Home Assistant

# Define your apps here
$instances = @(
    @{ Name = 'Readarr';   IP = '10.0.0.10'; Port = 8787; Shortcut = 'Readarr.lnk';   WebhookId = 'readarr_instance_down';   CheckProcess = $false; CheckPort = $true  }
    @{ Name = 'Sonarr';    IP = '10.0.0.10'; Port = 8987; Shortcut = 'Sonarr.lnk';    WebhookId = 'sonarr_instance_down';    CheckProcess = $true;  CheckPort = $true  }
    @{ Name = 'Radarr';    IP = '10.0.0.10'; Port = 7878; Shortcut = 'Radarr.lnk';    WebhookId = 'radarr_instance_down';    CheckProcess = $true;  CheckPort = $true  }
    @{ Name = 'Kavita';    IP = '10.0.0.10'; Port = 5005; Shortcut = 'Kavita.lnk';    WebhookId = 'kavita_instance_down';    CheckProcess = $true;  CheckPort = $true  }
    @{ Name = 'Ombi';      IP = '10.0.0.10'; Port = 5000; Shortcut = 'Ombi.lnk';      WebhookId = 'ombi_instance_down';      CheckProcess = $true;  CheckPort = $true  }
    @{ Name = 'Lidarr';    IP = '10.0.0.10'; Port = 8686; Shortcut = 'Lidarr.lnk';    WebhookId = 'lidarr_instance_down';    CheckProcess = $true;  CheckPort = $true  }
    @{ Name = 'Prowlarr';  IP = '10.0.0.10'; Port = 6969; Shortcut = 'Prowlarr.lnk';  WebhookId = 'prowlarr_instance_down';  CheckProcess = $true;  CheckPort = $false }
    @{ Name = 'NZBGet';    IP = '10.0.0.10'; Port = 6789; Shortcut = 'NZBGet.lnk';    WebhookId = 'nzbget_instance_down';    CheckProcess = $true;  CheckPort = $true  }
    @{ Name = 'Suwayomi';  IP = '10.0.0.10'; Port = 4567; Shortcut = 'Suwayomi.lnk';  WebhookId = 'suwayomi_instance_down';  CheckProcess = $true;  CheckPort = $true  }
    @{ Name = 'Speakarr';  IP = '10.0.0.10'; Port = 8777; Shortcut = 'Speakarr.lnk';  WebhookId = 'speakarr_instance_down';  CheckProcess = $false; CheckPort = $true  }
) | ForEach-Object {
    [pscustomobject]@{
        Name         = $_.Name
        IP           = $_.IP
        Port         = $_.Port
        Shortcut     = Join-Path $shortcutPath $_.Shortcut
        WebhookId    = $_.WebhookId
        CheckProcess = $_.CheckProcess
        CheckPort    = $_.CheckPort
    }
}


# --- INTERNAL SETUP (NO NEED TO TOUCH) ---

$scriptDirectory = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$logName = "SelfHostedChecker_$timestamp.log"
$logLocation = $scriptDirectory
$downInstances = @()

function Write-Log {
    param ($Message, $Path = "$logLocation\$logName")
    $t = Get-Date -Format 'HH:mm:ss'
    $msg = "[$t] $Message"
    Write-Output $msg
    if ($logToFile) { $msg | Out-File -FilePath $Path -Append }
}

Write-Log "START ====================="

$instances | ForEach-Object {
    $processCheck = $null
    $portCheck = $false
    $shouldCheckProcess = $_.CheckProcess
    $shouldCheckPort = $_.CheckPort

    if ($shouldCheckProcess -or $shouldCheckPort) {
        Write-Log "Checking if $($_.Name) is online"
    }

    $processStatus = $false
    if ($shouldCheckProcess) {
        Write-Log "Checking process $($_.Name) in Task Manager..."
        $processCheck = Get-Process -Name $_.Name -ErrorAction SilentlyContinue
        if ($processCheck) {
            Write-Log "$($_.Name) process is running!"
            $processStatus = $true
        } else {
            Write-Log "$($_.Name) process is NOT running."
        }
    }

    $portStatus = $false
    if ($shouldCheckPort -and !$processStatus) {
        Write-Log "Checking port $($_.Port)..."
        $portCheck = (Test-NetConnection $_.IP -Port $_.Port -WarningAction SilentlyContinue).TcpTestSucceeded
        if ($portCheck) {
            Write-Log "$($_.Name) port is up and running!"
            $portStatus = $true
        } else {
            Write-Log "$($_.Name) port is down."
        }
    }

    if ($processStatus -eq $false -and $portStatus -eq $false) {
        Write-Log "$($_.Name) is down."
        $downInstances += $_
    }
}

$downInstances | ForEach-Object {
    $instance = $_
    $attempt = 1
    $maxRetries = 3
    $retrySucceeded = $false

    while ($attempt -le $maxRetries -and !$retrySucceeded) {
        Write-Log "Retrying check for $($instance.Name) (Attempt $attempt)..."

        Write-Log "Launching shortcut for $($instance.Name)..."
        Start-Process $instance.Shortcut

        Start-Sleep -Seconds 300

        $processStatus = $false
        $portStatus = $false

        if ($instance.CheckProcess) {
            Write-Log "Rechecking process $($instance.Name)..."
            $processCheck = Get-Process -Name $instance.Name -ErrorAction SilentlyContinue
            if ($processCheck) {
                Write-Log "$($instance.Name) process is running after retry!"
                $processStatus = $true
                $retrySucceeded = $true
            } else {
                Write-Log "$($instance.Name) process is still NOT running."
            }
        }

        if ($instance.CheckPort -and !$retrySucceeded) {
            Write-Log "Rechecking port $($instance.Port)..."
            $portCheck = (Test-NetConnection $instance.IP -Port $instance.Port -WarningAction SilentlyContinue).TcpTestSucceeded
            if ($portCheck) {
                Write-Log "$($instance.Name) port is up after retry!"
                $portStatus = $true
                $retrySucceeded = $true
            } else {
                Write-Log "$($instance.Name) port is still down."
            }
        }

        if (!$retrySucceeded) {
            Write-Log "Retry failed for $($instance.Name). Waiting 5 minutes before next attempt..."
            $attempt++
        }
    }

    if (!$retrySucceeded) {
        Write-Log "Sending Webhook to Home Assistant about $($instance.Name) being down after retries."

        if ([string]::IsNullOrWhiteSpace($homeAssistantIP)) {
            Write-Log "[ERROR] Home Assistant IP is not defined. Cannot send webhook."
            return
        }

        $body = @{
            instance = $instance.Name
            message  = "$($instance.Name) is not running, even after retrying."
        }

        $webhookUrl = [string]::Format("http://{0}:8123/api/webhook/{1}", $homeAssistantIP, $instance.WebhookId)
        Write-Log "Webhook URL: $webhookUrl"

        try {
            $response = Invoke-RestMethod -Uri $webhookUrl -Method POST -Body ($body | ConvertTo-Json -Depth 2) -ContentType "application/json"
            Write-Log "Webhook sent for $($instance.Name): $($response | Out-String)"
        } catch {
            Write-Log "[ERROR] Failed to send Webhook for $($instance.Name): $_"
        }
    }
}

Write-Log 'END ====================='
Start-Sleep -Seconds 45  # Keeps the window open for 45 seconds before closing