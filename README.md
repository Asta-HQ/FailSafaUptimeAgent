# Failsafe Uptime Agent

The official uptime and monitoring agent for the [Asta Failsafe](https://failsafe.asta.cx) platform. The agent establishes a secure WebSocket connection to the backend, monitors infrastructure, and supports automatic updates and system daemon integration.

---

### 🐧 Linux (Bash)

For Linux, we provide an installation script that detects your system architecture, downloads the correct binary to `/usr/local/bin/failsafe_agent`, and optionally sets it up directly as a systemd service.

#### 1. Download Binary Only (without service installation)
```bash
curl -sL https://raw.githubusercontent.com/Asta-HQ/FailSafaUptimeAgent/refs/heads/main/install.sh | sudo bash

```

#### 2. Download AND directly start as a systemd service

```bash
curl -sL https://raw.githubusercontent.com/Asta-HQ/FailSafaUptimeAgent/refs/heads/main/install.sh | sudo bash -s -- --token "YOUR_AGENT_TOKEN"

```


---

### 🪟 Windows (Batch)

On Windows, the agent is placed under `C:\Program Files\FailsafeAgent\` and can be registered as a native Windows service.

> **Important:** Run Command Prompt (CMD) or PowerShell as **Administrator**!

#### 1. Download Binary Only

Download the [`install.bat`](https://raw.githubusercontent.com/Asta-HQ/FailSafaUptimeAgent/refs/heads/main/install.bat) script and run it, or execute it from an administrator CMD:

```cmd
install.bat
```

#### 2. Download AND register & start as a Windows service

```cmd
install.bat --token "YOUR_AGENT_TOKEN"
```
---

## ⚙️ CLI Commands & Options

The agent supports various command-line arguments for manual operation, service management, and updates.

| Flag | Description | Example |
| --- | --- | --- |
| `--token` | Authentication token for the Failsafe server (**Mandatory** for start/service) | `failsafe_agent --token "xyz"` |
| `--server` | Overrides the default backend server address (Default: `api.failsafe.asta.cx`) | `failsafe_agent --token "xyz" --server "192.168.1.50:4400"` |
| `--service install` | Registers the agent as a systemd service (Linux) | `sudo failsafe_agent --service install --token "xyz"` |
| `--service uninstall` | Removes the systemd service | `sudo failsafe_agent --service uninstall` |
| `--update` | Pulls the latest release from GitHub, stops the service, updates the binary, and restarts | `sudo failsafe_agent --update` |
| `--update [tag]` | Pulls a specific release tag (e.g., `v1.0.0`) | `sudo failsafe_agent --update v0.1.0` |

---

## 🛠 Manual Development & Build

If you want to compile the agent locally from source:

```bash
# Clone the repository
git clone https://github.com/Asta-HQ/FailSafaUptimeAgent.git
cd FailSafaUptimeAgent

# Build (e.g., for Linux)
go build -o failsafe_agent src/main.go
```
