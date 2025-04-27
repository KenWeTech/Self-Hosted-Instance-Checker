# ================================
# SELF-HOSTED INSTANCE CHECKER
# ================================

# --- USER SETTINGS (EDIT THIS SECTION) ---

$logToFile     = $false    # Set to $true to turn on logs  
$maxLogFiles   = 10  # Maximum number of log files to keep in the script directory
$shortcutPath  = "$env:USERPROFILE\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup"  # Default is your startup folder

# Gobal Endpoints for Alerts
$enableWebhookAlerts = $true   # Home Assistant - Set to $false to turn off
$enableNtfyAlerts    = $false  # Ntfy - Set to $true to turn on
$enableGotifyAlerts  = $false  # Gotify - Set to $true to turn on

$homeAssistantIP = "10.0.0.2"  # Enter the IP address for Home Assistant for webhook use
$ntfyTopicURL    = "https://ntfy.sh/selfhosted-alerts" # Ntfy topic URL
$gotifyURL       = "http://gotify.yourdomain.com/message" # Gotify URL
$gotifyToken     = "your_gotify_token" # Gotify token

# Define your apps here
$instances = @(
    @{ Name = 'Readarr';   IP = '10.0.0.10'; Port = 8787; Shortcut = 'Readarr.lnk';   WebhookId = 'readarr_instance_down';   CheckProcess = $false; CheckPort = $true;  RetryCount = 2 }
    @{ Name = 'Sonarr';    IP = '10.0.0.10'; Port = 8987; Shortcut = 'Sonarr.lnk';    WebhookId = 'sonarr_instance_down';    CheckProcess = $true;  CheckPort = $true;  RetryCount = 3 }
    @{ Name = 'Radarr';    IP = '10.0.0.10'; Port = 7878; Shortcut = 'Radarr.lnk';    WebhookId = 'radarr_instance_down';    CheckProcess = $true;  CheckPort = $true;  RetryCount = 0 }
    @{ Name = 'Kavita';    IP = '10.0.0.10'; Port = 5005; Shortcut = 'Kavita.lnk';    WebhookId = 'kavita_instance_down';    CheckProcess = $true;  CheckPort = $true;  RetryCount = 3 }
    @{ Name = 'Ombi';      IP = '10.0.0.10'; Port = 5000; Shortcut = 'Ombi.lnk';      WebhookId = 'ombi_instance_down';      CheckProcess = $true;  CheckPort = $true;  RetryCount = 2 }
    @{ Name = 'Lidarr';    IP = '10.0.0.10'; Port = 8686; Shortcut = 'Lidarr.lnk';    WebhookId = 'lidarr_instance_down';    CheckProcess = $true;  CheckPort = $true;  RetryCount = 1 }
    @{ Name = 'Prowlarr';  IP = '10.0.0.10'; Port = 6969; Shortcut = 'Prowlarr.lnk';  WebhookId = 'prowlarr_instance_down';  CheckProcess = $true;  CheckPort = $false; RetryCount = 0 }
    @{ Name = 'NZBGet';    IP = '10.0.0.10'; Port = 6789; Shortcut = 'NZBGet.lnk';    WebhookId = 'nzbget_instance_down';    CheckProcess = $true;  CheckPort = $true;  RetryCount = 2 }
    @{ Name = 'Suwayomi';  IP = '10.0.0.10'; Port = 4567; Shortcut = 'Suwayomi.lnk';  WebhookId = 'suwayomi_instance_down';  CheckProcess = $true;  CheckPort = $true;  RetryCount = 2 }
    @{ Name = 'Speakarr';  IP = '10.0.0.10'; Port = 8777; Shortcut = 'Speakarr.lnk';  WebhookId = 'speakarr_instance_down';  CheckProcess = $false; CheckPort = $true;  RetryCount = 1 }
) | ForEach-Object {
    [pscustomobject]@{
        Name         = $_.Name
        IP           = $_.IP
        Port         = $_.Port
        Shortcut     = Join-Path $shortcutPath $_.Shortcut
        WebhookId    = $_.WebhookId
        CheckProcess = $_.CheckProcess
        CheckPort    = $_.CheckPort
        RetryCount   = $_.RetryCount
        SendWebhook  = if ($_.ContainsKey('SendWebhook')) { $_.SendWebhook } else { $enableWebhookAlerts }
        SendNtfy     = if ($_.ContainsKey('SendNtfy'))     { $_.SendNtfy }     else { $enableNtfyAlerts }
        SendGotify   = if ($_.ContainsKey('SendGotify'))   { $_.SendGotify }   else { $enableGotifyAlerts }
    }
}

# --- INTERNAL SETUP (NO NEED TO TOUCH) ---

$scriptDirectory = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$logName = "SelfHostedChecker_$timestamp.log"
$logLocation = $scriptDirectory
$downInstances = @()

# Cleanup old logs if above threshold
if ($logToFile) {
    $logFiles = Get-ChildItem -Path $logLocation -Filter "SelfHostedChecker_*.log" | Sort-Object LastWriteTime -Descending
    if ($logFiles.Count -gt $maxLogFiles) {
        $logFiles | Select-Object -Skip $maxLogFiles | Remove-Item -Force
    }
}

function Write-Log {
    param ($Message, $Path = "$logLocation\$logName")
    $t = Get-Date -Format 'HH:mm:ss'
    $msg = "[$t] $Message"
    Write-Output $msg
    if ($logToFile) { $msg | Out-File -FilePath $Path -Append }
}

Write-Log "START ====================="

$downInstances = @()
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

    if (
		($_.CheckProcess -and -not $processStatus) -and
		($_.CheckPort -and -not $portStatus)
	) {
		Write-Log "$($_.Name) is down."
		$downInstances += $_
	}

}

$downInstances | ForEach-Object {
    $instance = $_
    $attempt = 1
    $maxRetries = $instance.RetryCount
    $retrySucceeded = $false

    if ($maxRetries -eq 0) {
        Write-Log "Skipping retries for $($instance.Name). Going straight to alerts..."
    } else {
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
    }

    if (!$retrySucceeded) {
        Write-Log "Sending Webhook to Home Assistant about $($instance.Name) being down after retries."

        # Webhook
        if ($instance.SendWebhook -and -not [string]::IsNullOrWhiteSpace($homeAssistantIP)) {
            $body = @{ instance = $instance.Name; message = "$($instance.Name) is not running, even after retrying." }
            $webhookUrl = [string]::Format("http://{0}:8123/api/webhook/{1}", $homeAssistantIP, $instance.WebhookId)
            try {
                Invoke-RestMethod -Uri $webhookUrl -Method POST -Body ($body | ConvertTo-Json -Depth 2) -ContentType "application/json"
                Write-Log "Webhook sent: $webhookUrl"
            } catch {
                Write-Log "[ERROR] Failed to send webhook to Home Assistant: $_"
            }
        }

        # ntfy
        if ($instance.SendNtfy -and -not [string]::IsNullOrWhiteSpace($ntfyTopicURL)) {
            try {
                Invoke-RestMethod -Uri $ntfyTopicURL -Method POST -Body "$($instance.Name) is down after checks." -ContentType "text/plain"
                Write-Log "ntfy alert sent."
            } catch {
                Write-Log "[ERROR] Failed to send ntfy alert: $_"
            }
        }

        # Gotify
        if ($instance.SendGotify -and -not [string]::IsNullOrWhiteSpace($gotifyURL)) {
            $gotifyPayload = @{ title = "SelfHosted Alert"; message = "$($instance.Name) is down after checks."; priority = 5 }
            try {
                Invoke-RestMethod -Uri $gotifyURL -Headers @{ 'X-Gotify-Key' = $gotifyToken } -Method POST -Body ($gotifyPayload | ConvertTo-Json -Depth 2) -ContentType "application/json"
                Write-Log "Gotify alert sent."
            } catch {
                Write-Log "[ERROR] Failed to send Gotify alert: $_"
            }
        }
    }
}

Write-Log 'END ====================='
Start-Sleep -Seconds 45  # Keeps the window open for 45 seconds before closing
