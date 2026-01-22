# MuleCube OS

<p align="center">
  <img src="https://mulecube.com/images/logo.png" alt="MuleCube" width="120">
</p>

<p align="center">
  <strong>Your offline world in a cube.</strong><br>
  A self-contained knowledge server with local AI, offline Wikipedia, mesh communications, and battery backup.
</p>

<p align="center">
  <a href="https://mulecube.com">Website</a> •
  <a href="https://mulecube.com/products/">Products</a> •
  <a href="https://mulecube.com/docs/">Documentation</a> •
  <a href="https://mulecube.com/faq/">FAQ</a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-Raspberry%20Pi%205-c51a4a?style=flat-square" alt="Platform">
  <img src="https://img.shields.io/badge/services-30+-blue?style=flat-square" alt="Services">
  <img src="https://img.shields.io/badge/license-GPL--3.0-green?style=flat-square" alt="License">
  <img src="https://img.shields.io/badge/status-pre--production-orange?style=flat-square" alt="Status">
</p>

---

## What is MuleCube?

MuleCube is a portable, battery-powered server that operates completely independently of internet, cellular, or grid power. It's designed for expeditions, emergency preparedness, field research, and anyone who needs reliable access to knowledge and communications when infrastructure fails.

Connect to the MuleCube WiFi hotspot from any device — phone, tablet, or laptop — and access a complete offline ecosystem of knowledge, AI assistants, and productivity tools.

## Related Repositories

| Repository | Description |
|------------|-------------|
| [mulecube-os](https://github.com/nuclearlighters/mulecube-os) | Core OS, Docker services, and device configuration (this repo) |
| [mulecube-dashboard](https://github.com/nuclearlighters/mulecube-dashboard) | Hugo-based web dashboard for the device |

## Features

### 30+ Pre-installed Services

| Category | Services |
|----------|----------|
| **Offline Knowledge** | Kiwix (Wikipedia 90GB+), Tileserver (offline maps), Calibre (e-books), medical references |
| **Local AI** | Ollama + Open WebUI with phi3, deepseek-r1, qwen2.5 models |
| **Mesh Communications** | Meshtastic gateway for encrypted LoRa messaging |
| **Productivity** | CryptPad, HedgeDoc, Excalidraw, Vaultwarden, LibreTranslate (49 languages) |
| **Media** | Jellyfin media server, Stirling PDF tools |
| **Infrastructure** | Pi-hole DNS, nginx reverse proxy, Syncthing file sync, Beszel monitoring |
| **Control Panel** | Web dashboard, container management, system diagnostics, backup/restore |

### Hardware Specifications

| Component | Specification |
|-----------|---------------|
| Computer | Raspberry Pi 5 (8GB or 16GB) |
| Storage | 256GB-1TB High-Endurance microSD/NVMe |
| Battery | 50Wh UPS (4x Samsung 18650, hot-swappable) |
| Runtime | 10-15 hours depending on workload |
| Enclosure | 90 x 90 x 65mm aluminum case |
| Connectivity | WiFi 6 AP, Gigabit Ethernet, USB 3.0 |

### Product Configurations

| Model | Description | Price |
|-------|-------------|-------|
| **DIY** | Build your own with this repo | Free |
| **Cube 8** | 8GB RAM, 30 services, ready to use | EUR 499 |
| **Cube 16** | 16GB RAM for larger AI models | EUR 549 |
| **Cube AI** | Hailo-10H NPU (40 TOPS) for vision and speech | EUR 699 |
| **Cube Sat** | Iridium satellite + Meshtastic bridge | EUR 849 |
| **Ultimate** | AI + Satellite, everything included | EUR 1199 |

---

## Quick Start (DIY)

### Prerequisites

- Raspberry Pi 5 (8GB recommended)
- 256GB+ microSD card or NVMe drive
- Raspberry Pi OS Lite (64-bit, Bookworm)
- Internet connection for initial setup

### One-Line Install

```bash
curl -fsSL https://raw.githubusercontent.com/nuclearlighters/mulecube-os/main/install.sh | sudo bash
```

### Manual Installation

```bash
# Clone the repository
git clone https://github.com/nuclearlighters/mulecube-os.git /srv

# Run the setup script
cd /srv
sudo ./scripts/setup.sh

# Start all services
sudo ./scripts/start-all.sh
```

After installation, connect to the `MuleCube` WiFi network and open `http://192.168.42.1` in your browser.

---

## Dashboard

The MuleCube dashboard is maintained in a separate repository: [mulecube-dashboard](https://github.com/nuclearlighters/mulecube-dashboard)

It provides at-a-glance system status and quick access to all services:

- **System Stats** — CPU, memory, disk, temperature, battery status
- **Service Grid** — One-click access to all 30+ services
- **Control Panel** — Container management, logs, terminal, diagnostics
- **Network Status** — WiFi clients, Ethernet, Meshtastic nodes

### Dashboard Installation

The dashboard is included automatically when using the one-line installer. For manual installation:

```bash
# Clone the dashboard repository
git clone https://github.com/nuclearlighters/mulecube-dashboard.git /srv/mulecube-dashboard

# Build the Hugo site
cd /srv/mulecube-dashboard
hugo --minify

# The nginx configuration in this repo will serve it automatically
```

---

## Repository Structure

```
/srv/                           # Main deployment directory
├── README.md
├── .gitignore                  # Excludes data directories
│
├── pihole/                     # DNS filtering and local DNS
│   └── docker-compose.yml
├── kiwix/                      # Offline Wikipedia
│   └── docker-compose.yml
├── ollama/                     # Local AI models
│   └── docker-compose.yml
├── openwebui/                  # AI chat interface
│   └── docker-compose.yml
├── cryptpad/                   # Collaborative documents
│   └── docker-compose.yml
├── vaultwarden/                # Password manager
│   └── docker-compose.yml
├── meshtastic/                 # LoRa mesh gateway
│   └── docker-compose.yml
│
├── mulecube-dashboard/         # Web dashboard (separate repo)
├── mulecube-controlpanel-user/ # User control panel services
│   ├── docker-compose.yml
│   ├── hw-monitor/             # Hardware monitoring API
│   ├── wifi-status/            # WiFi client tracking
│   └── ...
├── mulecube-controlpanel-admin/ # Admin services (on-demand)
│   ├── docker-compose.yml
│   ├── ttyd/                   # Web terminal
│   ├── dozzle/                 # Log viewer
│   └── ...
│
├── scripts/                    # Deployment and maintenance
│   ├── setup.sh
│   ├── start-all.sh
│   └── backup.sh
│
└── docs/                       # Documentation
    ├── INSTALL.md
    ├── SERVICES.md
    └── HARDWARE.md
```

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     MuleCube Device                          │
│  ┌─────────────────────────────────────────────────────────┐│
│  │                    Docker Engine                         ││
│  │  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐       ││
│  │  │ Pi-hole │ │  Kiwix  │ │ Ollama  │ │CryptPad │  ...  ││
│  │  └─────────┘ └─────────┘ └─────────┘ └─────────┘       ││
│  └─────────────────────────────────────────────────────────┘│
│  ┌─────────────────────────────────────────────────────────┐│
│  │              Control Panel Services                      ││
│  │  hw-monitor │ wifi-status │ watchdog │ diagnostics      ││
│  └─────────────────────────────────────────────────────────┘│
│  ┌─────────────────────────────────────────────────────────┐│
│  │                 System Services                          ││
│  │  hostapd (WiFi AP) │ dnsmasq │ nginx │ systemd          ││
│  └─────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────┘
         │                    │                    │
    WiFi Clients         Ethernet            USB Devices
   (192.168.42.x)       (optional)          (storage, etc.)
```

---

## Status

**Pre-production** — MuleCube is currently gauging interest before the first production run.

- [Register your interest](https://mulecube.com/interest/) to be notified when units are available
- [Join the discussion](https://github.com/nuclearlighters/mulecube-os/discussions) for questions and feedback
- [Report issues](https://github.com/nuclearlighters/mulecube-os/issues) for bugs and feature requests

## Contributing

Contributions are welcome! Please read our [Contributing Guide](CONTRIBUTING.md) before submitting PRs.

Areas where help is needed:

- Documentation improvements
- New service integrations
- Hardware enclosure designs
- Testing on different Pi 5 configurations
- Translations

## License

This project is licensed under the [GNU General Public License v3.0](LICENSE).

- **Code:** GPL-3.0
- **Documentation:** [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/)
- **Hardware designs:** [CERN OHL v2](https://ohwr.org/cern_ohl_s_v2.txt)

## Links

| Resource | URL |
|----------|-----|
| Website | [mulecube.com](https://mulecube.com) |
| Documentation | [mulecube.com/docs](https://mulecube.com/docs/) |
| Live Demo | [demo.mulecube.com](https://demo.mulecube.com) |
| GitLab (primary) | [gitlab.nuclearlighters.net](https://gitlab.nuclearlighters.net/products/mulecube/os) |
| Contact | hello@mulecube.com |

## Acknowledgments

MuleCube builds on the incredible work of many open source projects:

[Raspberry Pi](https://www.raspberrypi.org/) •
[Docker](https://www.docker.com/) •
[Kiwix](https://www.kiwix.org/) •
[Ollama](https://ollama.ai/) •
[Pi-hole](https://pi-hole.net/) •
[Meshtastic](https://meshtastic.org/) •
[Hugo](https://gohugo.io/)

---

<p align="center">
  Built in the Netherlands by <a href="https://nuclearlighters.net">Nuclear Lighters Inc.</a>
</p>