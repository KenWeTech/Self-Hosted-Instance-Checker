# Self-Hosted Instance Checker

[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1+-blue.svg)](https://docs.microsoft.com/en-us/powershell/)

**Keep your self-hosted ecosystem running smoothly with the Self-Hosted Instance Checker!**

This Windows PowerShell script is designed to monitor the online status of your self-hosted applications and services running on your Windows machine. It provides two key methods to help you manage downtime: automatically launching a shortcut to attempt a restart when an instance is offline, or sending webhook notifications to your Home Assistant instance to alert you of the status, allowing for broader home automation responses.

## Key Features

* **Automated Instance Monitoring:** Periodically checks if your specified self-hosted applications are online and reachable by verifying either the process name in Task Manager, the TCP port, or both.
* **Configurable Checks:** Define the name, IP address, port, associated shortcut, and Home Assistant webhook ID for each instance you want to monitor.
* **Automatic Shortcut Launch:** If an instance is detected as offline, the script can automatically launch a predefined Windows shortcut (e.g., a shortcut to the application's executable or a restart script).
* **Home Assistant Integration:** Sends webhook notifications to your Home Assistant instance when an instance is detected as down, enabling you to create alerts, automations, and dashboards to track the health of your services.
* **Retry Mechanism:** Implements a retry mechanism to attempt restarting an offline instance by launching the shortcut multiple times with a defined delay before sending a Home Assistant notification.
* **Logging:** Offers an option to log the script's activity to a file for troubleshooting and monitoring.
* **Easy Configuration:** User-friendly configuration section within the script to define the applications you want to monitor and their associated settings.
* **Task Scheduler Friendly:** Includes a `win_run.cmd` file for easy execution via the Windows Task Scheduler, allowing for automated, scheduled monitoring.

## Getting Started

### Prerequisites

* **Windows Operating System:** This script is designed for and tested on Windows.
* **PowerShell 5.1 or later:** Ensure you have PowerShell version 5.1 or a more recent version installed on your system.
* **Home Assistant (Optional):** If you want to utilize the Home Assistant webhook notification feature, you need a running Home Assistant instance with the Webhook integration enabled. You'll also need to define unique `WebhookId` values for each instance you want to report to Home Assistant.
* **Shortcuts (Optional):** If you want to use the automatic shortcut launch feature, you need to have valid Windows shortcut files (`.lnk`) created for your self-hosted applications. The script assumes these shortcuts are located in your Startup folder by default, but this can be adjusted.

### Installation

1.  **Download the Script:** Download the `SelfHostedInstancesChecker.ps1` file and the `win_run.cmd` file from the project repository to a directory on your Windows machine.
2.  **Configuration:** Open the `SelfHostedInstancesChecker.ps1` file in a text editor (like Notepad or PowerShell ISE).
3.  **Edit User Settings:** Carefully review and modify the **`--- USER SETTINGS (EDIT THIS SECTION) ---`** block at the beginning of the script:
    * **`$logToFile`:** Set this to `$true` to enable logging to a file in the same directory as the script, or `$false` to disable logging.
    * **`$shortcutPath`:** This variable defaults to your Windows Startup folder. If your application shortcuts are located elsewhere, you can modify this path.
    * **`$homeAssistantIP`:** Enter the IP address of your Home Assistant server. If you don't use Home Assistant webhooks, you can leave this blank.
    * **`$instances`:** This is an array where you define each self-hosted application you want to monitor. For each application, create a new hash table (`@{}`) with the following keys:
        * **`Name`:** A descriptive name for your instance (e.g., 'Readarr'). This name is used in logs and Home Assistant notifications.
        * **`IP`:** The IP address where your instance is hosted.
        * **`Port`:** The TCP port your instance uses.
        * **`Shortcut`:** The filename of the Windows shortcut (`.lnk`) used to launch or restart the application (e.g., 'Readarr.lnk'). This shortcut should exist in the path specified by `$shortcutPath`.
        * **`WebhookId`:** A unique identifier for this instance that you will use in your Home Assistant webhook trigger (e.g., 'readarr_instance_down'). This is only relevant if you are using Home Assistant notifications.
        * **`CheckProcess`:** Set to `$true` if you want the script to check if a process with the same `Name` is running in Task Manager. Set to `$false` otherwise.
        * **`CheckPort`:** Set to `$true` if you want the script to check if the specified `IP` and `Port` are reachable. Set to `$false` otherwise.
            * **Important:** You can choose to check only the process, only the port, or both for each instance.
4.  **Save the Script:** Save the changes you made to the `SelfHostedInstancesChecker.ps1` file.


#### Example Configuration:

```powershell
# --- USER SETTINGS (EDIT THIS SECTION) ---

$logToFile     = $true
$shortcutPath  = "$env:USERPROFILE\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup"
$homeAssistantIP = "192.168.1.100"

# Define your apps here
$instances = @(
    @{ Name = 'Plex Media Server'; IP = '127.0.0.1'; Port = 32400; Shortcut = 'Plex Media Server.lnk'; WebhookId = 'plex_down'; CheckProcess = $true; CheckPort = $true }
    @{ Name = 'qBittorrent';      IP = '127.0.0.1'; Port = 8080;  Shortcut = 'qBittorrent.lnk';      WebhookId = 'qbittorrent_down'; CheckProcess = $true; CheckPort = $true }
    @{ Name = 'MyWebApp';         IP = '10.0.1.50'; Port = 80;    Shortcut = 'WebApp Shortcut.lnk';   WebhookId = 'webapp_down'; CheckProcess = $false; CheckPort = $true }
) | ForEach-Object {
    [pscustomobject]@{
        Name        = $_.Name
        IP          = $_.IP
        Port        = $_.Port
        Shortcut    = Join-Path $shortcutPath $_.Shortcut
        WebhookId   = $_.WebhookId
        CheckProcess = $_.CheckProcess
        CheckPort   = $_.CheckPort
    }
}
```

### Usage

You can run the script manually or automate it using the Windows Task Scheduler.

#### Manual Execution

1.  Open PowerShell.
2.  Navigate to the directory where you saved the `SelfHostedInstancesChecker.ps1` file.
3.  Execute the script using the command:
    ```powershell
    .\SelfHostedInstancesChecker.ps1
    ```
    A PowerShell window will open and display the script's output. You can close this window once the script has finished its checks.

#### Automated Execution with Task Scheduler

Using the Task Scheduler allows the script to run periodically in the background without requiring manual intervention. The included `win_run.cmd` file simplifies this process.

1.  **Open Task Scheduler:** Search for "Task Scheduler" in the Windows search bar and open it.
2.  **Create a Basic Task:** In the right-hand pane, click "Create Basic Task...".
3.  **Name and Description:** Enter a name for the task (e.g., "Self-Hosted Checker") and an optional description. Click "Next".
4.  **Trigger:** Choose how often you want the script to run (e.g., "Hourly", "Daily", "Weekly", "When the computer starts"). Configure the specific schedule as needed and click "Next".
5.  **Action:** Select "Start a program" and click "Next".
6.  **Program/script:** Browse to the location where you saved the `win_run.cmd` file and select it. The "Add arguments (optional)" and "Start in (optional)" fields can be left blank. Click "Next".
7.  **Finish:** Review the task settings and click "Finish".

The script will now run automatically according to the schedule you defined. The `win_run.cmd` file ensures that the PowerShell script is executed correctly without keeping a PowerShell window open in the background.

### Home Assistant Webhook Integration

If an instance is detected as down after the configured retries, the script will send a POST request to the following URL for each affected instance:

```
http://YOUR_HOME_ASSISTANT_IP:8123/api/webhook/YOUR_WEBHOOK_ID
```

* Replace `YOUR_HOME_ASSISTANT_IP` with the actual IP address of your Home Assistant server (as configured in the `$homeAssistantIP` variable).
* Replace `YOUR_WEBHOOK_ID` with the unique `WebhookId` you defined for that specific instance in the `$instances` array.

The POST request will have a JSON body containing the following information:

```json
{
  "instance": "Friendly Name of Your Instance",
  "message": "Friendly Name of Your Instance is not running, even after retrying."
}
```

You can then create an automation in Home Assistant that is triggered by this webhook ID to perform actions such as sending notifications to your phone, turning on a visual indicator, or attempting more advanced recovery steps.

### Contributing

If you'd like to contribute to this project, feel free to open issues or submit pull requests.

### License

This project is licensed under the [MIT License](https://opensource.org/licenses/MIT).
```
