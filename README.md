
# Self-Hosted Instance Checker

[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1+-blue.svg)](https://docs.microsoft.com/en-us/powershell/)

**Keep your self-hosted ecosystem running smoothly with the Self-Hosted Instance Checker!**

This Windows PowerShell script is designed to monitor the online status of your self-hosted applications and services running on your Windows machine and across your network. It provides mechanisms to attempt recover of local applications by automatically launching Windows shortcuts, or send push notification alerts via **Home Assistant Webhooks**, **ntfy**, and **Gotify** when services go down.

## Key Features

* **Automated Instance Monitoring:** Periodically checks if your specified self-hosted applications are online and reachable by verifying either the process name in Task Manager, the TCP port, or both.
* **Local & Remote Network Checking:** Can check open ports on **remote devices** (NAS, Docker host, Raspberry Pi, another PC) across your local network if your network and firewall rules permit.
  > **Note on Remote Monitoring:** Shortcut auto-restarts only function for local applications running on the machine hosting this script. If a remote instance goes down, the script will only be able to send alerts.
* **Automatic Shortcut Launch:** Automatically launches predefined Windows shortcuts (`.lnk`) to attempt restarting offline local instances.
* **Configurable Notification Options:** Customizable alert titles, priorities, and emojis/tags across Home Assistant, ntfy, and Gotify.
* **Ntfy Integration:** Full support for ntfy topics with custom notification titles, priority levels, emojis/tags, and optional bearer token authentication.
* **Gotify Integration:** Support for Gotify servers using modern Bearer token header authentication, customized alert titles, and configurable priority levels.
* **Home Assistant Integration:** Sends webhook notifications to your Home Assistant instance when an instance is detected as down, enabling you to create alerts, automations, and dashboards to track the health of your services.
* **Retry Mechanism:** Configurable number of retry attempts per instance before firing off alerts. Setting retries to `0` goes straight to notifications.
* **Log File Management:** Configurable file logging with automatic cleanup to retain only a maximum defined number of historical log files.
* **Easy Configuration:** User-friendly configuration section within the script to define the applications you want to monitor and their associated settings.
* **Task Scheduler Friendly:** Includes a `win_run.cmd` launcher for easy execution via the Windows Task Scheduler, allowing for automated, scheduled monitoring.

---

## Getting Started

### Prerequisites

* **Windows Operating System:** Designed for and tested on Windows.
* **PowerShell 5.1 or later:** Pre-installed on modern Windows systems.
* **Home Assistant (Optional):** Requires a reachable Home Assistant instance and configured Webhook IDs.
* **Ntfy (Optional):** Requires access to an ntfy server (e.g., `ntfy.sh` or self-hosted). Token-authenticated topics supported.
* **Gotify (Optional):** Requires a running Gotify instance and an Application Token.
* **Shortcuts (Optional):** Windows shortcut files (`.lnk`) placed in the startup folder (or specified directory) for local application auto-restarts.

---

### Installation & Configuration

1. **Download:** Place `SelfHostedInstancesChecker.ps1` and `win_run.cmd` in the same directory on your Windows machine.
2. **Configuration:** Open `SelfHostedInstancesChecker.ps1` in a text editor (e.g., VS Code or Notepad).
3. **User Settings:** Edit the `--- USER SETTINGS (EDIT THIS SECTION) ---` block at the top of the script:

#### Available User Settings

| Setting | Type | Description |
| --- | --- | --- |
| `$logToFile` | `Boolean` | Set to `$true` to enable file logging. |
| `$maxLogFiles` | `Integer` | Maximum number of log files to keep in the script directory. |
| `$shortcutPath` | `String` | Path to folder containing restart shortcuts (Defaults to Windows Startup folder). |
| `$enableWebhookAlerts` | `Boolean` | Global toggle for Home Assistant webhook alerts. |
| `$enableNtfyAlerts` | `Boolean` | Global toggle for ntfy push alerts. |
| `$enableGotifyAlerts` | `Boolean` | Global toggle for Gotify push alerts. |
| `$alertTitle` | `String` | Notification header title used for ntfy and Gotify alerts. |
| `$homeAssistantIP` | `String` | IP address or hostname of your Home Assistant server. |
| `$ntfyTopicURL` | `String` | Full URL to your ntfy topic (e.g., `https://ntfy.sh/my-alerts`). |
| `$ntfyToken` | `String` | (Optional) Bearer token for password-protected ntfy topics. |
| `$ntfyPriority` | `String` | ntfy message priority (`max`, `urgent`, `high`, `default`, `low`, `min`). |
| `$ntfyTags` | `String` | Comma-separated ntfy tags or emojis (e.g., `warning,rotating_light`). |
| `$gotifyURL` | `String` | URL endpoint for your Gotify server (`http://gotify.domain.com/message`). |
| `$gotifyToken` | `String` | Application token generated in Gotify. |
| `$gotifyPriority` | `Integer` | Gotify notification priority level (e.g., `5`). |

#### Instance Definition Keys

Within the `$instances` array, define each monitored service:

* **`Name`**: Descriptive name of the service.
* **`IP`**: IP address (use `127.0.0.1` or `10.0.0.10` for local services, or remote IP for network services).
* **`Port`**: TCP port number.
* **`Shortcut`**: Local `.lnk` filename for application restarts.
* **`WebhookId`**: Unique Webhook ID for Home Assistant.
* **`CheckProcess`**: Set to `$true` to check Windows Task Manager process.
* **`CheckPort`**: Set to `$true` to check TCP network port availability.
* **`RetryCount`**: Number of restart attempts before sending alerts.
* **`SendWebhook` / `SendNtfy` / `SendGotify`**: (Optional) Per-instance boolean overrides for global alert toggles.

---

### Example Configuration

```powershell
# --- USER SETTINGS (EDIT THIS SECTION) ---

$logToFile     = $false    # Set to $true to turn on logs  
$maxLogFiles   = 10        # Maximum log files to retain
$shortcutPath  = "$env:USERPROFILE\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup"

# Global Endpoints for Alerts
$enableWebhookAlerts = $true   # Home Assistant
$enableNtfyAlerts    = $false  # Ntfy
$enableGotifyAlerts  = $false  # Gotify

$alertTitle          = "SelfHosted Alert"

$homeAssistantIP = "10.0.0.2"

# Ntfy Settings
$ntfyTopicURL    = "[https://ntfy.sh/selfhosted-alerts](https://ntfy.sh/selfhosted-alerts)"
$ntfyToken       = "" # Optional token
$ntfyPriority    = "urgent"
$ntfyTags        = "warning,rotating_light"

# Gotify Settings
$gotifyURL       = "[http://gotify.yourdomain.com/message](http://gotify.yourdomain.com/message)"
$gotifyToken     = "your_gotify_token"
$gotifyPriority  = 5

# Define your apps here
$instances = @(
    # Local application with process and port check + 3 retries
    @{ Name = 'Sonarr';    IP = '127.0.0.1'; Port = 8987; Shortcut = 'Sonarr.lnk'; WebhookId = 'sonarr_down'; CheckProcess = $true; CheckPort = $true; RetryCount = 3 }
    
    # Remote service (e.g. NAS/Docker container) - port check only, 0 retries (straight to alert)
    @{ Name = 'Unraid NAS'; IP = '10.0.0.50'; Port = 80;   Shortcut = 'None.lnk';   WebhookId = 'unraid_down'; CheckProcess = $false; CheckPort = $true; RetryCount = 0; SendNtfy = $true }
)

```

---

## Usage

### Manual Execution

Open PowerShell, navigate to the folder, and run:

```powershell
.\SelfHostedInstancesChecker.ps1

```

### Automated Execution (Windows Task Scheduler)

Using the Task Scheduler allows the script to run periodically in the background without requiring manual intervention. The included `win_run.cmd` file simplifies this process.

1.  **Open Task Scheduler:** Search for "Task Scheduler" in the Windows search bar and open it.
2.  **Create a Basic Task:** In the right-hand pane, click "Create Basic Task...".
3.  **Name and Description:** Enter a name for the task (e.g., "Self-Hosted Checker") and an optional description. Click "Next".
4.  **Trigger:** Choose how often you want the script to run (e.g., "Hourly", "Daily", "Weekly", "When the computer starts"). Configure the specific schedule as needed and click "Next".
5.  **Action:** Select "Start a program" and click "Next".
6.  **Program/script:** Browse to the location where you saved the `win_run.cmd` file and select it. The "Add arguments (optional)" and "Start in (optional)" fields can be left blank. Click "Next".
7.  **Finish:** Review the task settings and click "Finish".

The script will now run automatically according to the schedule you defined. The `win_run.cmd` file ensures that the PowerShell script is executed correctly without keeping a PowerShell window open in the background.

---

## Alerting Integrations

### Home Assistant Webhooks

Sends a JSON POST request to `http://<HA_IP>:8123/api/webhook/<WebhookId>`:

```json
{
  "instance": "Sonarr",
  "message": "Sonarr is not running, even after retrying."
}

```

### ntfy

Sends a POST request to `$ntfyTopicURL` formatted with HTTP headers:

* **Headers:** `Title`, `Priority`, `Tags`, and `Authorization: Bearer <Token>` (if configured).
* **Body:** `<Instance Name> is down after checks.`

### Gotify

Sends a POST request to `$gotifyURL` formatted with JSON body and Bearer token headers:

```json
{
  "title": "SelfHosted Alert",
  "message": "Sonarr is down after checks.",
  "priority": 5
}

```

---

## License

This project is licensed under the [MIT License](https://opensource.org/licenses/MIT).

```

```
