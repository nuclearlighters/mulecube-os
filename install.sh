#!/bin/bash
# ============================================================================
# MuleCube One-Line Installer
# ============================================================================
# Usage: curl -fsSL https://raw.githubusercontent.com/nuclearlighters/mulecube/main/install.sh | sudo bash
#
# This script installs MuleCube on a fresh Raspberry Pi 5 running
# Raspberry Pi OS Lite (64-bit, Bookworm).
#
# What it does:
#   1. Installs Docker and dependencies
#   2. Clones the MuleCube repository to /srv
#   3. Configures WiFi Access Point (hostapd)
#   4. Sets up networking (dnsmasq, iptables)
#   5. Starts core services
#
# License: MIT
# Website: https://mulecube.com
# ============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
REPO_URL="https://github.com/nuclearlighters/mulecube.git"
INSTALL_DIR="/srv"
WIFI_SSID="MuleCube"
WIFI_PASS="mulecube"
WIFI_IP="192.168.42.1"
WIFI_SUBNET="192.168.42.0/24"
WIFI_DHCP_START="192.168.42.10"
WIFI_DHCP_END="192.168.42.250"

# ============================================================================
# Helper Functions
# ============================================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "Please run as root: sudo bash install.sh"
        exit 1
    fi
}

check_platform() {
    if grep -q "Raspberry Pi 5" /proc/cpuinfo 2>/dev/null; then
        log_success "Detected Raspberry Pi 5"
    elif grep -q "Raspberry Pi" /proc/cpuinfo 2>/dev/null; then
        log_warn "Detected Raspberry Pi (not Pi 5) - some features may not work"
        read -p "Continue anyway? [y/N] " -n 1 -r
        echo
        [[ ! $REPLY =~ ^[Yy]$ ]] && exit 1
    else
        log_warn "This doesn't appear to be a Raspberry Pi"
        read -p "Continue anyway? [y/N] " -n 1 -r
        echo
        [[ ! $REPLY =~ ^[Yy]$ ]] && exit 1
    fi
}

check_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        if [[ "$ID" == "debian" || "$ID" == "raspbian" ]] && [[ "$VERSION_CODENAME" == "bookworm" ]]; then
            log_success "Detected $PRETTY_NAME"
        else
            log_warn "Expected Raspberry Pi OS Bookworm, found: $PRETTY_NAME"
        fi
    fi
}

check_internet() {
    log_info "Checking internet connectivity..."
    if ping -c 1 github.com &> /dev/null; then
        log_success "Internet connection OK"
    else
        log_error "No internet connection. Please connect to the internet first."
        exit 1
    fi
}

# ============================================================================
# Installation Functions
# ============================================================================

install_dependencies() {
    log_info "Installing system dependencies..."
    apt-get update -qq
    apt-get install -y -qq \
        git \
        curl \
        wget \
        jq \
        htop \
        vim \
        i2c-tools \
        hostapd \
        dnsmasq \
        iptables \
        netfilter-persistent \
        iptables-persistent \
        avahi-daemon
    log_success "Dependencies installed"
}

install_docker() {
    if command -v docker &> /dev/null; then
        log_success "Docker already installed: $(docker --version)"
    else
        log_info "Installing Docker..."
        curl -fsSL https://get.docker.com | sh
        usermod -aG docker pi 2>/dev/null || true
        log_success "Docker installed"
    fi
    
    # Enable and start Docker
    systemctl enable docker
    systemctl start docker
    
    # Install docker-compose plugin if not present
    if ! docker compose version &> /dev/null; then
        log_info "Installing Docker Compose plugin..."
        apt-get install -y -qq docker-compose-plugin
    fi
    log_success "Docker Compose ready: $(docker compose version --short)"
}

clone_repository() {
    log_info "Setting up MuleCube repository..."
    
    if [ -d "$INSTALL_DIR/.git" ]; then
        log_info "Repository exists, pulling updates..."
        cd "$INSTALL_DIR"
        git pull
    else
        if [ -d "$INSTALL_DIR" ] && [ "$(ls -A $INSTALL_DIR)" ]; then
            log_warn "/srv is not empty. Backing up to /srv.backup..."
            mv "$INSTALL_DIR" "/srv.backup.$(date +%Y%m%d%H%M%S)"
        fi
        git clone "$REPO_URL" "$INSTALL_DIR"
    fi
    
    cd "$INSTALL_DIR"
    log_success "Repository cloned to $INSTALL_DIR"
}

configure_wifi_ap() {
    log_info "Configuring WiFi Access Point..."
    
    # Detect WiFi interface
    WIFI_INTERFACE=$(iw dev | awk '$1=="Interface"{print $2}' | head -1)
    if [ -z "$WIFI_INTERFACE" ]; then
        log_warn "No WiFi interface found. Skipping AP configuration."
        return
    fi
    log_info "Using WiFi interface: $WIFI_INTERFACE"
    
    # Stop services during configuration
    systemctl stop hostapd 2>/dev/null || true
    systemctl stop dnsmasq 2>/dev/null || true
    
    # Unblock WiFi
    rfkill unblock wlan 2>/dev/null || true
    
    # Configure hostapd
    cat > /etc/hostapd/hostapd.conf << EOF
# MuleCube WiFi Access Point Configuration
interface=$WIFI_INTERFACE
driver=nl80211
ssid=$WIFI_SSID
hw_mode=g
channel=7
wmm_enabled=0
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=$WIFI_PASS
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP
rsn_pairwise=CCMP

# Enable WiFi 5 (802.11ac) if supported
ieee80211n=1
ieee80211ac=1
EOF

    # Point hostapd to config
    sed -i 's|^#DAEMON_CONF=.*|DAEMON_CONF="/etc/hostapd/hostapd.conf"|' /etc/default/hostapd
    echo 'DAEMON_CONF="/etc/hostapd/hostapd.conf"' > /etc/default/hostapd
    
    # Configure dnsmasq
    cat > /etc/dnsmasq.d/mulecube.conf << EOF
# MuleCube DHCP and DNS Configuration
interface=$WIFI_INTERFACE
bind-interfaces
dhcp-range=$WIFI_DHCP_START,$WIFI_DHCP_END,255.255.255.0,24h
dhcp-option=option:router,$WIFI_IP
dhcp-option=option:dns-server,$WIFI_IP

# Local DNS entries
address=/mulecube.local/$WIFI_IP
address=/cube.local/$WIFI_IP

# Captive portal detection
address=/connectivitycheck.gstatic.com/$WIFI_IP
address=/www.msftconnecttest.com/$WIFI_IP
address=/captive.apple.com/$WIFI_IP
EOF

    # Configure static IP for WiFi interface
    cat > /etc/dhcpcd.conf.mulecube << EOF
# MuleCube network configuration
interface $WIFI_INTERFACE
    static ip_address=$WIFI_IP/24
    nohook wpa_supplicant
EOF

    # Append to dhcpcd.conf if not already present
    if ! grep -q "MuleCube network configuration" /etc/dhcpcd.conf 2>/dev/null; then
        cat /etc/dhcpcd.conf.mulecube >> /etc/dhcpcd.conf
    fi
    
    log_success "WiFi AP configured (SSID: $WIFI_SSID, Password: $WIFI_PASS)"
}

configure_networking() {
    log_info "Configuring networking and NAT..."
    
    # Enable IP forwarding
    echo "net.ipv4.ip_forward=1" > /etc/sysctl.d/90-mulecube.conf
    sysctl -p /etc/sysctl.d/90-mulecube.conf
    
    # Get default internet interface (usually eth0)
    INTERNET_IF=$(ip route | grep default | awk '{print $5}' | head -1)
    WIFI_INTERFACE=$(iw dev | awk '$1=="Interface"{print $2}' | head -1)
    
    if [ -n "$INTERNET_IF" ] && [ -n "$WIFI_INTERFACE" ]; then
        # Configure NAT (for internet sharing when Ethernet is connected)
        iptables -t nat -A POSTROUTING -o "$INTERNET_IF" -j MASQUERADE
        iptables -A FORWARD -i "$INTERNET_IF" -o "$WIFI_INTERFACE" -m state --state RELATED,ESTABLISHED -j ACCEPT
        iptables -A FORWARD -i "$WIFI_INTERFACE" -o "$INTERNET_IF" -j ACCEPT
        
        # Save iptables rules
        netfilter-persistent save
    fi
    
    log_success "Networking configured"
}

enable_i2c() {
    log_info "Enabling I2C for hardware monitoring..."
    
    # Enable I2C in config.txt
    if ! grep -q "^dtparam=i2c_arm=on" /boot/firmware/config.txt 2>/dev/null; then
        echo "dtparam=i2c_arm=on" >> /boot/firmware/config.txt
    fi
    
    # Load I2C module
    modprobe i2c-dev 2>/dev/null || true
    
    # Add to modules
    if ! grep -q "^i2c-dev" /etc/modules; then
        echo "i2c-dev" >> /etc/modules
    fi
    
    log_success "I2C enabled"
}

create_scripts() {
    log_info "Creating helper scripts..."
    
    mkdir -p "$INSTALL_DIR/scripts"
    
    # Create start-all.sh
    cat > "$INSTALL_DIR/scripts/start-all.sh" << 'EOF'
#!/bin/bash
# Start all MuleCube services
cd /srv

echo "Starting MuleCube services..."

# Find all docker-compose files and start them
for dir in */; do
    if [ -f "${dir}docker-compose.yml" ]; then
        echo "  Starting ${dir%/}..."
        (cd "$dir" && docker compose up -d) 2>/dev/null || true
    fi
done

echo ""
echo "✅ Services started. Access dashboard at http://192.168.42.1"
EOF
    chmod +x "$INSTALL_DIR/scripts/start-all.sh"
    
    # Create stop-all.sh
    cat > "$INSTALL_DIR/scripts/stop-all.sh" << 'EOF'
#!/bin/bash
# Stop all MuleCube services
cd /srv

echo "Stopping MuleCube services..."

for dir in */; do
    if [ -f "${dir}docker-compose.yml" ]; then
        echo "  Stopping ${dir%/}..."
        (cd "$dir" && docker compose down) 2>/dev/null || true
    fi
done

echo "✅ All services stopped"
EOF
    chmod +x "$INSTALL_DIR/scripts/stop-all.sh"
    
    # Create status.sh
    cat > "$INSTALL_DIR/scripts/status.sh" << 'EOF'
#!/bin/bash
# Show MuleCube status
echo "╔═══════════════════════════════════════╗"
echo "║         MuleCube Status               ║"
echo "╚═══════════════════════════════════════╝"
echo ""
echo "📦 Docker containers:"
docker ps --format "   {{.Names}}: {{.Status}}" | head -20
TOTAL=$(docker ps -q | wc -l)
echo ""
echo "   Total running: $TOTAL"
echo ""
echo "🌡️  CPU Temperature: $(vcgencmd measure_temp 2>/dev/null || cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null | awk '{print $1/1000"°C"}' || echo 'N/A')"
echo "💾 Disk Usage: $(df -h /srv | awk 'NR==2{print $5 " used of " $2}')"
echo "🧠 Memory: $(free -h | awk 'NR==2{print $3 " / " $2}')"
echo ""
echo "🌐 Network:"
echo "   WiFi AP: $(systemctl is-active hostapd)"
echo "   DHCP: $(systemctl is-active dnsmasq)"
echo ""
EOF
    chmod +x "$INSTALL_DIR/scripts/status.sh"
    
    log_success "Helper scripts created"
}

enable_services() {
    log_info "Enabling system services..."
    
    # Unmask and enable hostapd
    systemctl unmask hostapd
    systemctl enable hostapd
    
    # Enable dnsmasq
    systemctl enable dnsmasq
    
    # Enable avahi for .local resolution
    systemctl enable avahi-daemon
    
    log_success "System services enabled"
}

print_summary() {
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║              MuleCube Installation Complete!                  ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "📁 Installation directory: $INSTALL_DIR"
    echo ""
    echo "🌐 WiFi Access Point:"
    echo "   SSID:     $WIFI_SSID"
    echo "   Password: $WIFI_PASS"
    echo "   IP:       $WIFI_IP"
    echo ""
    echo "📋 Next steps:"
    echo "   1. Reboot to apply all changes:"
    echo "      sudo reboot"
    echo ""
    echo "   2. After reboot, start services:"
    echo "      cd /srv && sudo ./scripts/start-all.sh"
    echo ""
    echo "   3. Connect to '$WIFI_SSID' WiFi and open:"
    echo "      http://192.168.42.1"
    echo ""
    echo "📖 Documentation: https://mulecube.com/docs/"
    echo "🐛 Report issues: https://github.com/nuclearlighters/mulecube/issues"
    echo ""
    echo "⚠️  IMPORTANT: You should change the default WiFi password!"
    echo "   Edit: /etc/hostapd/hostapd.conf"
    echo ""
}

# ============================================================================
# Main Installation
# ============================================================================

main() {
    echo ""
    echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║              MuleCube Installer v1.0                          ║${NC}"
    echo -e "${BLUE}║         Your offline world in a cube.                         ║${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    check_root
    check_platform
    check_os
    check_internet
    
    echo ""
    log_info "Starting installation..."
    echo ""
    
    install_dependencies
    install_docker
    clone_repository
    configure_wifi_ap
    configure_networking
    enable_i2c
    create_scripts
    enable_services
    
    print_summary
}

# Run main function
main "$@"
