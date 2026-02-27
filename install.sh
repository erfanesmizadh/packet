#!/bin/bash
#==========================================================================
# AVASH Tunnel Manager
# Version: 1.0
# Multi-Protocol Raw Packet Tunnel - Firewall Bypass
# Telegram: https://t.me/AVASH_NET
#
# Supported Protocols:
#   • KCP   - Fast UDP-based reliable transport (anti-QoS)
#   • WireGuard - Modern VPN / Tunnel (kernel-level, fastest)
#   • GRE   - Generic Routing Encapsulation (site-to-site)
#   • IPsec - Encrypted site-to-site tunnel (strongest security)
#   • SIT   - IPv6-in-IPv4 tunneling (6in4)
#   • IPIP  - IP-in-IP simple encapsulation
#==========================================================================

# ─── Colors ───────────────────────────────────────────────────────────────
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly CYAN='\033[0;36m'
readonly BLUE='\033[0;34m'
readonly MAGENTA='\033[0;35m'
readonly WHITE='\033[1;37m'
readonly ORANGE='\033[0;33m'
readonly PURPLE='\033[0;35m'
readonly BOLD='\033[1m'
readonly DIM='\033[2m'
readonly NC='\033[0m'

# ─── Script Configuration ─────────────────────────────────────────────────
readonly SCRIPT_VERSION="1.0"
readonly MANAGER_NAME="avash-tunnel"
readonly MANAGER_PATH="/usr/local/bin/$MANAGER_NAME"
readonly CONFIG_DIR="/etc/avash-tunnel"
readonly SERVICE_DIR="/etc/systemd/system"
readonly BIN_DIR="/usr/local/bin"
readonly BACKUP_DIR="/root/avash-backups"
readonly LOG_DIR="/var/log/avash-tunnel"
readonly PAQET_REPO="hanselime/paqet"

# ─── Telegram / Bot ───────────────────────────────────────────────────────
readonly TELEGRAM_CHANNEL="@AVASH_NET"
readonly TELEGRAM_URL="https://t.me/AVASH_NET"
readonly BOT_CONFIG_FILE="$CONFIG_DIR/bot.conf"
readonly BOT_LOG_FILE="$LOG_DIR/bot.log"
readonly BOT_SCRIPT="/opt/avash-tunnel/bot.sh"
readonly BOT_SERVICE="avash-bot"

# ─── Defaults ─────────────────────────────────────────────────────────────
readonly DEFAULT_LISTEN_PORT="8888"
readonly DEFAULT_WG_PORT="51820"
readonly DEFAULT_KCP_MODE="fast"
readonly DEFAULT_ENCRYPTION="aes-128-gcm"
readonly DEFAULT_CONNECTIONS="4"
readonly DEFAULT_MTU="1350"
readonly DEFAULT_AUTO_RESTART="1hour"

# ─── Protocol List ────────────────────────────────────────────────────────
declare -A TUNNEL_PROTOCOLS=(
    ["1"]="kcp:KCP (Raw Packet / Anti-Censorship):paqet"
    ["2"]="wireguard:WireGuard (Modern VPN / Fastest):wg"
    ["3"]="gre:GRE (Generic Routing Encapsulation):ip"
    ["4"]="ipsec:IPsec (Encrypted Site-to-Site):strongswan"
    ["5"]="sit:SIT / 6in4 (IPv6 over IPv4):ip"
    ["6"]="ipip:IPIP (IP in IP Encapsulation):ip"
)

# ─── KCP Modes ────────────────────────────────────────────────────────────
declare -A KCP_MODES=(
    ["0"]="normal:Normal speed / Normal latency / Low CPU"
    ["1"]="fast:Balanced speed / Low latency / Normal CPU"
    ["2"]="fast2:High speed / Lower latency / Medium CPU"
    ["3"]="fast3:Max speed / Very low latency / High CPU"
    ["4"]="manual:Advanced manual configuration"
)

# ─── Encryption Options ───────────────────────────────────────────────────
declare -A ENCRYPTION_OPTIONS=(
    ["1"]="aes-128-gcm:Very high security / Fastest (Recommended)"
    ["2"]="aes-256-gcm:Maximum security / Slower"
    ["3"]="aes-128-cfb:High security / Fast"
    ["4"]="chacha20:Modern cipher / Low CPU"
    ["5"]="none:No encryption / Maximum speed (Insecure)"
)

# ─── Auto-Restart Intervals ───────────────────────────────────────────────
declare -A RESTART_INTERVALS=(
    ["5min"]="*/5 * * * *"
    ["15min"]="*/15 * * * *"
    ["30min"]="*/30 * * * *"
    ["1hour"]="0 */1 * * *"
    ["6hour"]="0 */6 * * *"
    ["12hour"]="0 */12 * * *"
    ["1day"]="0 0 * * *"
)

# ─── IP Detection Services ────────────────────────────────────────────────
readonly IP_SERVICES=("ifconfig.me" "icanhazip.com" "api.ipify.org" "checkip.amazonaws.com")

# ─── MTU Sizes to Test ────────────────────────────────────────────────────
readonly MTU_TESTS=("1500" "1470" "1400" "1350" "1300" "1200" "1100" "1000")

# ─── DNS Servers ──────────────────────────────────────────────────────────
readonly DNS_SERVERS=("8.8.8.8" "1.1.1.1" "208.67.222.222")

# ═══════════════════════════════════════════════════════════════════════════
# UTILITY FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════

print_step()    { echo -e "${BLUE}[*]${NC} $1"; }
print_success() { echo -e "${GREEN}[✓]${NC} $1"; }
print_error()   { echo -e "${RED}[✗]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
print_info()    { echo -e "${CYAN}[i]${NC} $1"; }
print_input()   { echo -e "${YELLOW}[?]${NC} $1"; }

pause() {
    local msg="${1:-Press Enter to continue...}"
    echo ""
    read -r -p "$msg"
}

# ─── Banner ───────────────────────────────────────────────────────────────
show_banner() {
    clear
    echo -e "${MAGENTA}"
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║                                                                  ║"
    echo "║    ██████╗ ██╗   ██╗ █████╗ ███████╗██╗  ██╗                   ║"
    echo "║   ██╔═══██╗██║   ██║██╔══██╗██╔════╝██║  ██║                   ║"
    echo "║   ███████║ ██║   ██║███████║███████╗███████║                   ║"
    echo "║   ██╔══██║  ██╗ ██╔╝██╔══██║╚════██║██╔══██║                   ║"
    echo "║   ██║  ██║   ████╔╝ ██║  ██║███████║██║  ██║                   ║"
    echo "║   ╚═╝  ╚═╝   ╚═══╝  ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝                   ║"
    echo "║                                                                  ║"
    echo "║          Multi-Protocol Tunnel Manager  v${SCRIPT_VERSION}              ║"
    echo "║          KCP • WireGuard • GRE • IPsec • SIT • IPIP            ║"
    echo "║                                                                  ║"
    echo "║              📢  Telegram: ${TELEGRAM_CHANNEL}                      ║"
    echo "║                                                                  ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# ─── Root Check ───────────────────────────────────────────────────────────
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root!"
        echo -e "${YELLOW}Run: sudo bash $0${NC}"
        exit 1
    fi
}

# ─── Detect OS ────────────────────────────────────────────────────────────
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$ID"
    elif [ -f /etc/redhat-release ]; then
        echo "rhel"
    else
        echo "$(uname -s | tr '[:upper:]' '[:lower:]')"
    fi
}

# ─── Detect Architecture ──────────────────────────────────────────────────
detect_arch() {
    local arch
    arch=$(uname -m)
    case $arch in
        x86_64|amd64)    echo "amd64" ;;
        aarch64|arm64)   echo "arm64" ;;
        armv7l|armhf)    echo "armv7" ;;
        i386|i686)       echo "386"   ;;
        *) print_error "Unsupported architecture: $arch"; return 1 ;;
    esac
}

# ─── Get Public IP ────────────────────────────────────────────────────────
get_public_ip() {
    for svc in "${IP_SERVICES[@]}"; do
        local ip
        ip=$(curl -4 -s --max-time 3 "$svc" 2>/dev/null)
        if [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo "$ip"; return 0
        fi
    done
    hostname -I 2>/dev/null | awk '{print $1}' || echo "Not Detected"
}

# ─── Get Network Info ─────────────────────────────────────────────────────
get_network_info() {
    NETWORK_INTERFACE=""
    LOCAL_IP=""
    GATEWAY_IP=""
    GATEWAY_MAC=""

    if command -v ip &>/dev/null; then
        NETWORK_INTERFACE=$(ip route | grep default | awk '{print $5}' | head -1)
        LOCAL_IP=$(ip -4 addr show "$NETWORK_INTERFACE" 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)
        GATEWAY_IP=$(ip route | grep default | awk '{print $3}' | head -1)

        if [ -n "$GATEWAY_IP" ]; then
            ping -c 1 -W 1 "$GATEWAY_IP" >/dev/null 2>&1 || true
            GATEWAY_MAC=$(ip neigh show "$GATEWAY_IP" 2>/dev/null | grep -oE '([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}' | head -1)
        fi
    fi
    NETWORK_INTERFACE="${NETWORK_INTERFACE:-eth0}"
    LOCAL_IP="${LOCAL_IP:-127.0.0.1}"
}

# ─── Validators ───────────────────────────────────────────────────────────
validate_ip() {
    local ip=$1
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        local IFS='.'
        read -ra octets <<< "$ip"
        for octet in "${octets[@]}"; do
            [[ $octet -gt 255 ]] && return 1
        done
        return 0
    fi
    return 1
}

validate_port() {
    [[ "$1" =~ ^[0-9]+$ ]] && [ "$1" -ge 1 ] && [ "$1" -le 65535 ]
}

clean_config_name() {
    local name="$1"
    name=$(echo "$name" | tr -cd '[:alnum:]-_')
    echo "${name:-tunnel}"
}

generate_secret_key() {
    if command -v openssl &>/dev/null; then
        openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c 32
    else
        tr -dc 'a-zA-Z0-9' </dev/urandom | head -c 32
    fi
}

generate_wg_keys() {
    if command -v wg &>/dev/null; then
        local privkey pubkey
        privkey=$(wg genkey)
        pubkey=$(echo "$privkey" | wg pubkey)
        echo "$privkey $pubkey"
    else
        echo "" ""
    fi
}

check_port_conflict() {
    local port="$1"
    if ss -tuln 2>/dev/null | grep -q ":${port} "; then
        print_warning "Port $port is already in use!"
        local pid
        pid=$(lsof -t -i:"$port" 2>/dev/null | head -1)
        if [ -n "$pid" ]; then
            local pname
            pname=$(ps -p "$pid" -o comm= 2>/dev/null || echo "unknown")
            print_info "Used by: $pname (PID: $pid)"
            read -r -p "Kill this process? (y/N): " kill_choice
            if [[ "$kill_choice" =~ ^[Yy]$ ]]; then
                kill -9 "$pid" 2>/dev/null || true
                sleep 1
                print_success "Process killed"
            else
                return 1
            fi
        fi
    fi
    return 0
}

# ─── Save iptables ────────────────────────────────────────────────────────
save_iptables() {
    if command -v netfilter-persistent &>/dev/null; then
        netfilter-persistent save >/dev/null 2>&1
    elif command -v iptables-save &>/dev/null; then
        mkdir -p /etc/iptables
        iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
    fi
}

# ─── Configure iptables for KCP ───────────────────────────────────────────
configure_iptables_kcp() {
    local port="$1"
    if ! command -v iptables &>/dev/null; then return 0; fi
    print_step "Configuring iptables for KCP port $port..."

    iptables -t raw -D PREROUTING -p tcp --dport "$port" -j NOTRACK 2>/dev/null || true
    iptables -t raw -D OUTPUT     -p tcp --sport "$port" -j NOTRACK 2>/dev/null || true
    iptables -t raw -A PREROUTING -p tcp --dport "$port" -j NOTRACK
    iptables -t raw -A OUTPUT     -p tcp --sport "$port" -j NOTRACK
    iptables -t mangle -D OUTPUT -p tcp --sport "$port" --tcp-flags RST RST -j DROP 2>/dev/null || true
    iptables -t mangle -A OUTPUT -p tcp --sport "$port" --tcp-flags RST RST -j DROP

    print_success "iptables configured for KCP on port $port"
    save_iptables
}

# ─── Configure iptables for WireGuard ────────────────────────────────────
configure_iptables_wg() {
    local port="$1" iface="$2"
    if ! command -v iptables &>/dev/null; then return 0; fi
    print_step "Configuring iptables for WireGuard port $port..."

    iptables -A INPUT   -p udp --dport "$port" -j ACCEPT 2>/dev/null || true
    iptables -A FORWARD -i "$iface" -j ACCEPT              2>/dev/null || true
    iptables -A FORWARD -o "$iface" -j ACCEPT              2>/dev/null || true
    iptables -t nat -A POSTROUTING -o "$NETWORK_INTERFACE" -j MASQUERADE 2>/dev/null || true

    print_success "iptables configured for WireGuard"
    save_iptables
}

# ─── Create systemd service ───────────────────────────────────────────────
create_systemd_service() {
    local name="$1" exec_cmd="$2" desc="${3:-Tunnel Service}"
    local svc_file="$SERVICE_DIR/avash-${name}.service"

    cat > "$svc_file" << EOF
[Unit]
Description=AVASH Tunnel - ${desc} (${name})
After=network.target
StartLimitIntervalSec=0

[Service]
Type=simple
ExecStart=${exec_cmd}
Restart=always
RestartSec=5
LimitNOFILE=65535
Environment="GOMAXPROCS=0"

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    print_success "Service created: avash-${name}"
}

# ─── Create WireGuard systemd service ─────────────────────────────────────
create_wg_service() {
    local iface="$1"
    local svc_file="$SERVICE_DIR/avash-wg-${iface}.service"

    cat > "$svc_file" << EOF
[Unit]
Description=AVASH WireGuard Tunnel - ${iface}
After=network.target
StartLimitIntervalSec=0

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/wg-quick up ${CONFIG_DIR}/wg/${iface}.conf
ExecStop=/usr/bin/wg-quick down ${CONFIG_DIR}/wg/${iface}.conf
Restart=no

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    print_success "WireGuard service created: avash-wg-${iface}"
}

# ─── Crontab management ───────────────────────────────────────────────────
add_cronjob() {
    local svc="$1" interval="$2"
    local cron_cmd="systemctl restart ${svc}"
    local cron_line="${RESTART_INTERVALS[$interval]} $cron_cmd"
    [ -z "${RESTART_INTERVALS[$interval]}" ] && { print_error "Invalid interval: $interval"; return 1; }

    (crontab -l 2>/dev/null | grep -v "$cron_cmd"; echo "$cron_line") | crontab -
    print_success "Auto-restart set: every $interval for $svc"
}

remove_cronjob() {
    local svc="$1"
    local cron_cmd="systemctl restart ${svc}"
    if crontab -l 2>/dev/null | grep -q "$cron_cmd"; then
        crontab -l 2>/dev/null | grep -v "$cron_cmd" | crontab -
        print_success "Cronjob removed for $svc"
    else
        print_info "No cronjob found for $svc"
    fi
}

view_cronjob() {
    local svc="$1"
    local cron_cmd="systemctl restart ${svc}"
    if crontab -l 2>/dev/null | grep -q "$cron_cmd"; then
        crontab -l 2>/dev/null | grep "$cron_cmd"
    else
        echo "  (none)"
    fi
}

# ─── compare floats ───────────────────────────────────────────────────────
compare_floats() {
    local v=$1 t=$2 op=$3
    if command -v bc &>/dev/null; then
        case $op in
            lt) (($(echo "$v < $t" | bc -l 2>/dev/null || echo 0))) ;;
            gt) (($(echo "$v > $t" | bc -l 2>/dev/null || echo 0))) ;;
        esac
    else
        case $op in
            lt) [[ ${v%.*} -lt ${t%.*} ]] ;;
            gt) [[ ${v%.*} -gt ${t%.*} ]] ;;
        esac
    fi
}

# ═══════════════════════════════════════════════════════════════════════════
# KCP (PAQET) CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════

get_latest_paqet_version() {
    local ver
    ver=$(curl -s "https://api.github.com/repos/${PAQET_REPO}/releases/latest" 2>/dev/null \
        | grep '"tag_name"' | cut -d'"' -f4)
    echo "${ver:-v1.0.0-alpha.16}"
}

install_paqet_binary() {
    local arch
    arch=$(detect_arch) || return 1
    local arch_name="$arch"
    [ "$arch" = "amd64" ] && arch_name="amd64"

    local latest
    latest=$(get_latest_paqet_version)
    local fname="paqet-linux-${arch_name}-${latest}.tar.gz"
    local url="https://github.com/${PAQET_REPO}/releases/download/${latest}/${fname}"

    print_step "Downloading Paqet $latest..."
    if ! curl -fsSL "$url" -o /tmp/paqet.tar.gz 2>/dev/null; then
        print_error "Download failed: $url"
        return 1
    fi

    mkdir -p /opt/paqet
    tar -xzf /tmp/paqet.tar.gz -C /opt/paqet 2>/dev/null
    rm -f /tmp/paqet.tar.gz

    local bin
    bin=$(find /opt/paqet -type f -name "*paqet*" | head -1)
    [ -z "$bin" ] && bin=$(find /opt/paqet -type f -executable | head -1)

    if [ -n "$bin" ]; then
        cp "$bin" "$BIN_DIR/paqet"
        chmod +x "$BIN_DIR/paqet"
        print_success "Paqet installed: $BIN_DIR/paqet"
    else
        print_error "Could not find Paqet binary in archive"
        return 1
    fi
}

get_manual_kcp_settings() {
    local nodelay interval resend nocongestion rcvwnd sndwnd

    read -r -p "[nodelay] 0-2 (default 1): " nodelay
    nodelay="${nodelay:-1}"
    read -r -p "[interval] ms (default 20): " interval
    interval="${interval:-20}"
    read -r -p "[resend] 0-N (default 1): " resend
    resend="${resend:-1}"
    read -r -p "[nocongestion] 0/1 (default 1): " nocongestion
    nocongestion="${nocongestion:-1}"
    read -r -p "[rcvwnd] (default 2048): " rcvwnd
    rcvwnd="${rcvwnd:-2048}"
    read -r -p "[sndwnd] (default 2048): " sndwnd
    sndwnd="${sndwnd:-2048}"

    echo "nodelay: $nodelay"
    echo "interval: $interval"
    echo "resend: $resend"
    echo "nocongestion: $nocongestion"
    echo "rcvwnd: $rcvwnd"
    echo "sndwnd: $sndwnd"
}

configure_kcp_server() {
    clear; show_banner
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  KCP Server Configuration (Abroad/Kharej)                        ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════╝${NC}\n"

    get_network_info
    local public_ip
    public_ip=$(get_public_ip)

    echo -e "${CYAN}Detected Network:${NC}"
    printf "  Interface : ${WHITE}%s${NC}\n" "${NETWORK_INTERFACE}"
    printf "  Local IP  : ${WHITE}%s${NC}\n" "${LOCAL_IP}"
    printf "  Public IP : ${GREEN}%s${NC}\n" "$public_ip"
    printf "  Gateway   : ${WHITE}%s${NC}\n" "${GATEWAY_MAC:-N/A}"
    echo ""

    # Name
    read -r -p "$(echo -e "${YELLOW}[1] Service Name (e.g: kcp-iran1): ${NC}")" config_name
    config_name=$(clean_config_name "${config_name:-kcp-server}")
    if [ -f "$CONFIG_DIR/kcp/${config_name}.yaml" ]; then
        print_warning "Config '$config_name' already exists!"
        read -r -p "Overwrite? (y/N): " ow
        [[ ! "$ow" =~ ^[Yy]$ ]] && return
    fi

    # Port
    read -r -p "$(echo -e "${YELLOW}[2] Listen Port (default: $DEFAULT_LISTEN_PORT): ${NC}")" port
    port="${port:-$DEFAULT_LISTEN_PORT}"
    validate_port "$port" || { print_error "Invalid port"; return; }
    check_port_conflict "$port" || return

    # Secret Key
    local secret_key
    secret_key=$(generate_secret_key)
    echo -e "${YELLOW}[3] Secret Key (auto-generated):${NC} ${GREEN}$secret_key${NC}"
    read -r -p "Use this key? (Y/n): " use_key
    if [[ "$use_key" =~ ^[Nn]$ ]]; then
        read -r -p "Enter custom secret key (min 8 chars): " secret_key
        [ ${#secret_key} -lt 8 ] && { print_error "Too short"; return; }
    fi

    # KCP Mode
    echo -e "\n${CYAN}[4] KCP Mode:${NC}"
    for k in 0 1 2 3 4; do
        IFS=':' read -r mname mdesc <<< "${KCP_MODES[$k]}"
        echo -e "  ${WHITE}[$k]${NC} ${mname} - ${DIM}${mdesc}${NC}"
    done
    read -r -p "Choose KCP mode [0-4] (default 1): " mode_choice
    mode_choice="${mode_choice:-1}"
    local mode_name kcp_extra=""
    case $mode_choice in
        0) mode_name="normal"  ;;
        1) mode_name="fast"    ;;
        2) mode_name="fast2"   ;;
        3) mode_name="fast3"   ;;
        4) mode_name="manual"
           echo -e "\n${YELLOW}Manual KCP Parameters:${NC}"
           kcp_extra=$(get_manual_kcp_settings) ;;
        *) mode_name="fast" ;;
    esac

    # Connections
    read -r -p "$(echo -e "${YELLOW}[5] Connections [1-32] (default: $DEFAULT_CONNECTIONS): ${NC}")" conn
    conn="${conn:-$DEFAULT_CONNECTIONS}"
    [[ ! "$conn" =~ ^[0-9]+$ ]] || [ "$conn" -lt 1 ] || [ "$conn" -gt 32 ] && conn="$DEFAULT_CONNECTIONS"

    # MTU
    read -r -p "$(echo -e "${YELLOW}[6] MTU [100-9000] (default: $DEFAULT_MTU): ${NC}")" mtu
    mtu="${mtu:-$DEFAULT_MTU}"
    [[ ! "$mtu" =~ ^[0-9]+$ ]] || [ "$mtu" -lt 100 ] || [ "$mtu" -gt 9000 ] && mtu="$DEFAULT_MTU"

    # Encryption
    echo -e "\n${CYAN}[7] Encryption:${NC}"
    for k in 1 2 3 4 5; do
        IFS=':' read -r ename edesc <<< "${ENCRYPTION_OPTIONS[$k]}"
        echo -e "  ${WHITE}[$k]${NC} ${ename} - ${DIM}${edesc}${NC}"
    done
    read -r -p "Choose [1-5] (default 1): " enc_choice
    enc_choice="${enc_choice:-1}"
    local encryption
    IFS=':' read -r encryption _ <<< "${ENCRYPTION_OPTIONS[$enc_choice]}"
    encryption="${encryption:-aes-128-gcm}"

    # Install paqet if needed
    if [ ! -f "$BIN_DIR/paqet" ]; then
        print_warning "Paqet binary not found. Installing..."
        install_paqet_binary || { print_error "Cannot install Paqet"; pause; return; }
    fi

    configure_iptables_kcp "$port"
    mkdir -p "$CONFIG_DIR/kcp"

    # Write YAML
    {
        echo "# AVASH KCP Server - $config_name"
        echo "# Generated: $(date)"
        echo "role: \"server\""
        echo "log:"
        echo "  level: \"info\""
        echo "listen:"
        echo "  addr: \":$port\""
        echo "network:"
        echo "  interface: \"$NETWORK_INTERFACE\""
        echo "  ipv4:"
        echo "    addr: \"$LOCAL_IP:$port\""
        [ -n "$GATEWAY_MAC" ] && echo "    router_mac: \"$GATEWAY_MAC\""
        echo "  tcp:"
        echo "    local_flag: [\"PA\"]"
        echo "transport:"
        echo "  protocol: \"kcp\""
        echo "  conn: $conn"
        echo "  kcp:"
        echo "    key: \"$secret_key\""
        echo "    mode: \"$mode_name\""
        echo "    block: \"$encryption\""
        echo "    mtu: $mtu"
        if [ "$mode_name" = "manual" ] && [ -n "$kcp_extra" ]; then
            while IFS= read -r line; do
                [ -n "$line" ] && echo "    $line"
            done <<< "$kcp_extra"
        fi
    } > "$CONFIG_DIR/kcp/${config_name}.yaml"

    create_systemd_service "kcp-${config_name}" "$BIN_DIR/paqet run -c $CONFIG_DIR/kcp/${config_name}.yaml" "KCP Tunnel"
    local svc="avash-kcp-${config_name}"
    systemctl enable "$svc" --now >/dev/null 2>&1
    sleep 2

    if systemctl is-active --quiet "$svc"; then
        add_cronjob "$svc" "$DEFAULT_AUTO_RESTART" >/dev/null 2>&1
        echo -e "\n${GREEN}╔══════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║  ✅  KCP Server Ready!                                             ║${NC}"
        echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        printf "  ${CYAN}%-16s${NC} : ${WHITE}%s${NC}\n" "Public IP"   "$public_ip"
        printf "  ${CYAN}%-16s${NC} : ${WHITE}%s${NC}\n" "Listen Port" "$port"
        printf "  ${CYAN}%-16s${NC} : ${WHITE}%s${NC}\n" "Connections" "$conn"
        printf "  ${CYAN}%-16s${NC} : ${WHITE}%s${NC}\n" "Mode"        "$mode_name"
        printf "  ${CYAN}%-16s${NC} : ${WHITE}%s${NC}\n" "Encryption"  "$encryption"
        printf "  ${CYAN}%-16s${NC} : ${WHITE}%s${NC}\n" "MTU"         "$mtu"
        echo ""
        echo -e "${YELLOW}  Secret Key (keep this for client):${NC}"
        echo -e "  ${GREEN}${BOLD}$secret_key${NC}"
        echo ""
    else
        print_error "Service failed to start!"
        systemctl status "$svc" --no-pager -l
    fi
    pause
}

configure_kcp_client() {
    clear; show_banner
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  KCP Client Configuration (Iran/Domestic)                         ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════╝${NC}\n"

    get_network_info

    read -r -p "$(echo -e "${YELLOW}[1] Service Name (e.g: kcp-client1): ${NC}")" config_name
    config_name=$(clean_config_name "${config_name:-kcp-client}")

    read -r -p "$(echo -e "${YELLOW}[2] Server IP (Kharej): ${NC}")" server_ip
    [ -z "$server_ip" ] && { print_error "Server IP required"; return; }
    validate_ip "$server_ip" || { print_error "Invalid IP"; return; }

    read -r -p "$(echo -e "${YELLOW}[3] Server Port (default: $DEFAULT_LISTEN_PORT): ${NC}")" server_port
    server_port="${server_port:-$DEFAULT_LISTEN_PORT}"
    validate_port "$server_port" || { print_error "Invalid port"; return; }

    read -r -p "$(echo -e "${YELLOW}[4] Secret Key (from server): ${NC}")" secret_key
    [ -z "$secret_key" ] && { print_error "Secret key required"; return; }

    echo -e "\n${CYAN}[5] KCP Mode:${NC}"
    for k in 0 1 2 3 4; do
        IFS=':' read -r mname mdesc <<< "${KCP_MODES[$k]}"
        echo -e "  ${WHITE}[$k]${NC} ${mname} - ${DIM}${mdesc}${NC}"
    done
    read -r -p "Choose KCP mode [0-4] (default 1): " mode_choice
    mode_choice="${mode_choice:-1}"
    local mode_name kcp_extra=""
    case $mode_choice in
        0) mode_name="normal" ;; 1) mode_name="fast" ;; 2) mode_name="fast2" ;;
        3) mode_name="fast3"  ;; 4) mode_name="manual"; kcp_extra=$(get_manual_kcp_settings) ;;
        *) mode_name="fast" ;;
    esac

    read -r -p "$(echo -e "${YELLOW}[6] Connections [1-32] (default: $DEFAULT_CONNECTIONS): ${NC}")" conn
    conn="${conn:-$DEFAULT_CONNECTIONS}"
    [[ ! "$conn" =~ ^[0-9]+$ ]] && conn="$DEFAULT_CONNECTIONS"

    read -r -p "$(echo -e "${YELLOW}[7] MTU (default: $DEFAULT_MTU): ${NC}")" mtu
    mtu="${mtu:-$DEFAULT_MTU}"

    echo -e "\n${CYAN}[8] Encryption:${NC}"
    for k in 1 2 3 4 5; do
        IFS=':' read -r ename edesc <<< "${ENCRYPTION_OPTIONS[$k]}"
        echo -e "  ${WHITE}[$k]${NC} ${ename} - ${DIM}${edesc}${NC}"
    done
    read -r -p "Choose [1-5] (default 1): " enc_choice
    enc_choice="${enc_choice:-1}"
    local encryption
    IFS=':' read -r encryption _ <<< "${ENCRYPTION_OPTIONS[$enc_choice]}"
    encryption="${encryption:-aes-128-gcm}"

    echo -e "\n${CYAN}[9] Traffic Mode:${NC}"
    echo -e "  ${WHITE}[1]${NC} Port Forwarding (Forward traffic from local port to server)"
    echo -e "  ${WHITE}[2]${NC} SOCKS5 Proxy (Create local SOCKS5 proxy)"
    read -r -p "Choose [1-2] (default 1): " traffic_mode

    local forward_config=""
    case "$traffic_mode" in
        2)
            local socks_port
            read -r -p "$(echo -e "${YELLOW}    SOCKS5 Listen Port (default 1080): ${NC}")" socks_port
            socks_port="${socks_port:-1080}"
            forward_config="socks5"
            ;;
        *)
            local fwd_ports
            read -r -p "$(echo -e "${YELLOW}    Forward Ports (e.g: 443,80,8443): ${NC}")" fwd_ports
            fwd_ports="${fwd_ports:-443}"
            forward_config="portforward:$fwd_ports"
            ;;
    esac

    if [ ! -f "$BIN_DIR/paqet" ]; then
        print_warning "Installing Paqet binary..."
        install_paqet_binary || { print_error "Cannot install Paqet"; pause; return; }
    fi

    mkdir -p "$CONFIG_DIR/kcp"

    {
        echo "# AVASH KCP Client - $config_name"
        echo "# Generated: $(date)"
        echo "role: \"client\""
        echo "log:"
        echo "  level: \"info\""
        echo "remote:"
        echo "  addr: \"$server_ip:$server_port\""
        echo "network:"
        echo "  interface: \"$NETWORK_INTERFACE\""
        echo "  ipv4:"
        echo "    addr: \"$LOCAL_IP:0\""
        [ -n "$GATEWAY_MAC" ] && echo "    router_mac: \"$GATEWAY_MAC\""
        echo "  tcp:"
        echo "    local_flag: [\"PA\"]"

        if [[ "$forward_config" == "socks5" ]]; then
            echo "socks5:"
            echo "  listen: \":${socks_port:-1080}\""
        else
            local ports="${forward_config#portforward:}"
            echo "forward:"
            IFS=',' read -ra plist <<< "$ports"
            for p in "${plist[@]}"; do
                p=$(echo "$p" | tr -d '[:space:]')
                validate_port "$p" && echo "  - \"$server_ip:$p\""
            done
        fi

        echo "transport:"
        echo "  protocol: \"kcp\""
        echo "  conn: $conn"
        echo "  kcp:"
        echo "    key: \"$secret_key\""
        echo "    mode: \"$mode_name\""
        echo "    block: \"$encryption\""
        echo "    mtu: $mtu"
        if [ "$mode_name" = "manual" ] && [ -n "$kcp_extra" ]; then
            while IFS= read -r line; do
                [ -n "$line" ] && echo "    $line"
            done <<< "$kcp_extra"
        fi
    } > "$CONFIG_DIR/kcp/${config_name}.yaml"

    create_systemd_service "kcp-${config_name}" "$BIN_DIR/paqet run -c $CONFIG_DIR/kcp/${config_name}.yaml" "KCP Client"
    local svc="avash-kcp-${config_name}"
    systemctl enable "$svc" --now >/dev/null 2>&1
    sleep 2

    if systemctl is-active --quiet "$svc"; then
        add_cronjob "$svc" "$DEFAULT_AUTO_RESTART" >/dev/null 2>&1
        print_success "KCP Client started successfully!"
        printf "  ${CYAN}%-14s${NC} : ${WHITE}%s${NC}\n" "Server"  "$server_ip:$server_port"
        printf "  ${CYAN}%-14s${NC} : ${WHITE}%s${NC}\n" "Mode"    "$mode_name"
        printf "  ${CYAN}%-14s${NC} : ${WHITE}%s${NC}\n" "Traffic" "$forward_config"
    else
        print_error "Service failed to start!"
        journalctl -u "$svc" -n 20 --no-pager
    fi
    pause
}

# ═══════════════════════════════════════════════════════════════════════════
# WIREGUARD CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════

install_wireguard() {
    local os
    os=$(detect_os)
    print_step "Installing WireGuard..."
    case $os in
        ubuntu|debian)
            apt-get update -qq >/dev/null 2>&1
            apt-get install -y wireguard wireguard-tools >/dev/null 2>&1 ;;
        centos|rhel|rocky|almalinux)
            yum install -y epel-release >/dev/null 2>&1
            yum install -y wireguard-tools kmod-wireguard >/dev/null 2>&1 ;;
        fedora)
            dnf install -y wireguard-tools >/dev/null 2>&1 ;;
        *)
            print_error "Please install WireGuard manually for your OS"
            return 1 ;;
    esac
    command -v wg &>/dev/null && print_success "WireGuard installed" || { print_error "WireGuard install failed"; return 1; }
}

configure_wireguard_server() {
    clear; show_banner
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  WireGuard Server Configuration                                   ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════╝${NC}\n"

    if ! command -v wg &>/dev/null; then
        print_warning "WireGuard not installed. Installing now..."
        install_wireguard || { pause; return; }
    fi

    get_network_info
    local public_ip
    public_ip=$(get_public_ip)

    read -r -p "$(echo -e "${YELLOW}[1] Interface Name (e.g: wg0): ${NC}")" wg_iface
    wg_iface="${wg_iface:-wg0}"
    wg_iface=$(echo "$wg_iface" | tr -cd 'a-zA-Z0-9_-')

    read -r -p "$(echo -e "${YELLOW}[2] Listen Port (default: $DEFAULT_WG_PORT): ${NC}")" wg_port
    wg_port="${wg_port:-$DEFAULT_WG_PORT}"
    validate_port "$wg_port" || { print_error "Invalid port"; return; }

    read -r -p "$(echo -e "${YELLOW}[3] Server Tunnel IP (e.g: 10.0.0.1): ${NC}")" tun_ip
    tun_ip="${tun_ip:-10.0.0.1}"

    read -r -p "$(echo -e "${YELLOW}[4] Tunnel Subnet CIDR (default: /24): ${NC}")" tun_cidr
    tun_cidr="${tun_cidr:-24}"

    read -r -p "$(echo -e "${YELLOW}[5] MTU (default: 1420): ${NC}")" wg_mtu
    wg_mtu="${wg_mtu:-1420}"

    read -r -p "$(echo -e "${YELLOW}[6] Enable IP Forwarding? (Y/n): ${NC}")" enable_fwd
    enable_fwd="${enable_fwd:-Y}"

    print_step "Generating WireGuard keys..."
    local privkey pubkey
    privkey=$(wg genkey)
    pubkey=$(echo "$privkey" | wg pubkey)

    if [[ "$enable_fwd" =~ ^[Yy]$ ]]; then
        echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
        echo "net.ipv6.conf.all.forwarding=1" >> /etc/sysctl.conf
        sysctl -p >/dev/null 2>&1
    fi

    mkdir -p "$CONFIG_DIR/wg"
    chmod 700 "$CONFIG_DIR/wg"

    cat > "$CONFIG_DIR/wg/${wg_iface}.conf" << EOF
# AVASH WireGuard Server - ${wg_iface}
# Generated: $(date)
# Public Key: ${pubkey}

[Interface]
PrivateKey = ${privkey}
Address = ${tun_ip}/${tun_cidr}
ListenPort = ${wg_port}
MTU = ${wg_mtu}
PostUp   = iptables -A FORWARD -i %i -j ACCEPT; iptables -t nat -A POSTROUTING -o ${NETWORK_INTERFACE} -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -t nat -D POSTROUTING -o ${NETWORK_INTERFACE} -j MASQUERADE

# --- Add clients below ---
# [Peer]
# PublicKey = <client_pubkey>
# AllowedIPs = 10.0.0.2/32
EOF
    chmod 600 "$CONFIG_DIR/wg/${wg_iface}.conf"

    create_wg_service "$wg_iface"
    local svc="avash-wg-${wg_iface}"
    systemctl enable "$svc" --now >/dev/null 2>&1
    sleep 2

    if systemctl is-active --quiet "$svc"; then
        add_cronjob "$svc" "$DEFAULT_AUTO_RESTART" >/dev/null 2>&1
        echo -e "\n${GREEN}╔══════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║  ✅  WireGuard Server Ready!                                       ║${NC}"
        echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════╝${NC}\n"
        printf "  ${CYAN}%-16s${NC} : ${WHITE}%s${NC}\n" "Public IP"   "$public_ip"
        printf "  ${CYAN}%-16s${NC} : ${WHITE}%s${NC}\n" "Listen Port" "$wg_port"
        printf "  ${CYAN}%-16s${NC} : ${WHITE}%s${NC}\n" "Tunnel IP"   "${tun_ip}/${tun_cidr}"
        printf "  ${CYAN}%-16s${NC} : ${WHITE}%s${NC}\n" "Interface"   "$wg_iface"
        echo ""
        echo -e "${YELLOW}  Server Public Key (give this to clients):${NC}"
        echo -e "  ${GREEN}${BOLD}$pubkey${NC}"
        echo ""
        echo -e "${CYAN}  Config: $CONFIG_DIR/wg/${wg_iface}.conf${NC}"
    else
        print_error "WireGuard failed to start!"
        journalctl -u "$svc" -n 20 --no-pager
    fi
    pause
}

configure_wireguard_client() {
    clear; show_banner
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  WireGuard Client Configuration                                   ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════╝${NC}\n"

    if ! command -v wg &>/dev/null; then
        print_warning "WireGuard not installed. Installing..."
        install_wireguard || { pause; return; }
    fi

    get_network_info

    read -r -p "$(echo -e "${YELLOW}[1] Interface Name (e.g: wg0): ${NC}")" wg_iface
    wg_iface="${wg_iface:-wg0}"

    read -r -p "$(echo -e "${YELLOW}[2] Client Tunnel IP (e.g: 10.0.0.2): ${NC}")" client_ip
    client_ip="${client_ip:-10.0.0.2}"

    read -r -p "$(echo -e "${YELLOW}[3] Server Public IP: ${NC}")" srv_ip
    [ -z "$srv_ip" ] && { print_error "Server IP required"; return; }

    read -r -p "$(echo -e "${YELLOW}[4] Server Port (default: $DEFAULT_WG_PORT): ${NC}")" srv_port
    srv_port="${srv_port:-$DEFAULT_WG_PORT}"

    read -r -p "$(echo -e "${YELLOW}[5] Server Public Key: ${NC}")" srv_pubkey
    [ -z "$srv_pubkey" ] && { print_error "Server public key required"; return; }

    read -r -p "$(echo -e "${YELLOW}[6] Allowed IPs (default: 0.0.0.0/0 = full tunnel): ${NC}")" allowed_ips
    allowed_ips="${allowed_ips:-0.0.0.0/0}"

    read -r -p "$(echo -e "${YELLOW}[7] DNS (default: 1.1.1.1): ${NC}")" wg_dns
    wg_dns="${wg_dns:-1.1.1.1}"

    read -r -p "$(echo -e "${YELLOW}[8] MTU (default: 1420): ${NC}")" wg_mtu
    wg_mtu="${wg_mtu:-1420}"

    print_step "Generating client keys..."
    local privkey pubkey
    privkey=$(wg genkey)
    pubkey=$(echo "$privkey" | wg pubkey)

    mkdir -p "$CONFIG_DIR/wg"
    chmod 700 "$CONFIG_DIR/wg"

    cat > "$CONFIG_DIR/wg/${wg_iface}.conf" << EOF
# AVASH WireGuard Client - ${wg_iface}
# Generated: $(date)

[Interface]
PrivateKey = ${privkey}
Address = ${client_ip}/32
DNS = ${wg_dns}
MTU = ${wg_mtu}

[Peer]
PublicKey = ${srv_pubkey}
Endpoint = ${srv_ip}:${srv_port}
AllowedIPs = ${allowed_ips}
PersistentKeepalive = 25
EOF
    chmod 600 "$CONFIG_DIR/wg/${wg_iface}.conf"

    create_wg_service "$wg_iface"
    local svc="avash-wg-${wg_iface}"
    systemctl enable "$svc" --now >/dev/null 2>&1
    sleep 2

    if systemctl is-active --quiet "$svc"; then
        add_cronjob "$svc" "$DEFAULT_AUTO_RESTART" >/dev/null 2>&1
        print_success "WireGuard Client started!"
        echo ""
        printf "  ${CYAN}%-16s${NC} : ${WHITE}%s${NC}\n" "Client IP"   "$client_ip"
        printf "  ${CYAN}%-16s${NC} : ${WHITE}%s${NC}\n" "Server"      "$srv_ip:$srv_port"
        printf "  ${CYAN}%-16s${NC} : ${WHITE}%s${NC}\n" "AllowedIPs"  "$allowed_ips"
        echo ""
        echo -e "${YELLOW}  Client Public Key (add this to server):${NC}"
        echo -e "  ${GREEN}${BOLD}$pubkey${NC}"
    else
        print_error "WireGuard client failed to start!"
        journalctl -u "$svc" -n 20 --no-pager
    fi
    pause
}

# ═══════════════════════════════════════════════════════════════════════════
# GRE TUNNEL CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════

configure_gre() {
    clear; show_banner
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  GRE Tunnel Configuration                                         ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════╝${NC}\n"

    echo -e "${CYAN}GRE (Generic Routing Encapsulation) creates a virtual tunnel between${NC}"
    echo -e "${CYAN}two servers. Fast but unencrypted — best combined with SSH/TLS.${NC}\n"

    get_network_info
    local public_ip
    public_ip=$(get_public_ip)

    read -r -p "$(echo -e "${YELLOW}[1] Tunnel Name (e.g: gre-iran): ${NC}")" tun_name
    tun_name=$(clean_config_name "${tun_name:-gre0}")

    read -r -p "$(echo -e "${YELLOW}[2] This Server IP (local): ${NC}")" local_ip_gre
    local_ip_gre="${local_ip_gre:-$LOCAL_IP}"

    read -r -p "$(echo -e "${YELLOW}[3] Remote Server IP (other side): ${NC}")" remote_ip_gre
    [ -z "$remote_ip_gre" ] && { print_error "Remote IP required"; return; }
    validate_ip "$remote_ip_gre" || { print_error "Invalid IP"; return; }

    read -r -p "$(echo -e "${YELLOW}[4] Tunnel Local IP (e.g: 172.16.0.1): ${NC}")" tun_local
    tun_local="${tun_local:-172.16.0.1}"

    read -r -p "$(echo -e "${YELLOW}[5] Tunnel Remote IP (e.g: 172.16.0.2): ${NC}")" tun_remote
    tun_remote="${tun_remote:-172.16.0.2}"

    read -r -p "$(echo -e "${YELLOW}[6] TTL (default: 255): ${NC}")" gre_ttl
    gre_ttl="${gre_ttl:-255}"

    print_step "Creating GRE tunnel: $tun_name"

    # Remove if exists
    ip tunnel del "$tun_name" 2>/dev/null || true

    # Create GRE tunnel
    ip tunnel add "$tun_name" mode gre \
        local "$local_ip_gre" remote "$remote_ip_gre" \
        ttl "$gre_ttl" 2>/dev/null

    if [ $? -ne 0 ]; then
        print_error "Failed to create GRE tunnel (is ip_gre kernel module loaded?)"
        modprobe ip_gre 2>/dev/null
        ip tunnel add "$tun_name" mode gre \
            local "$local_ip_gre" remote "$remote_ip_gre" ttl "$gre_ttl"
    fi

    ip link set "$tun_name" up
    ip addr add "${tun_local}/30" dev "$tun_name" 2>/dev/null || true
    ip link set "$tun_name" mtu 1476

    mkdir -p "$CONFIG_DIR/gre"
    cat > "$CONFIG_DIR/gre/${tun_name}.conf" << EOF
# AVASH GRE Tunnel Config - $tun_name
# Generated: $(date)
TUNNEL_NAME="$tun_name"
LOCAL_IP="$local_ip_gre"
REMOTE_IP="$remote_ip_gre"
TUN_LOCAL="$tun_local"
TUN_REMOTE="$tun_remote"
TTL="$gre_ttl"
EOF

    # Create persistent startup service
    cat > "$SERVICE_DIR/avash-gre-${tun_name}.service" << EOF
[Unit]
Description=AVASH GRE Tunnel - ${tun_name}
After=network.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/bash -c 'modprobe ip_gre; ip tunnel add ${tun_name} mode gre local ${local_ip_gre} remote ${remote_ip_gre} ttl ${gre_ttl}; ip link set ${tun_name} up; ip addr add ${tun_local}/30 dev ${tun_name}; ip link set ${tun_name} mtu 1476'
ExecStop=/bin/bash -c 'ip tunnel del ${tun_name}'

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable "avash-gre-${tun_name}" >/dev/null 2>&1

    # Verify
    if ip link show "$tun_name" 2>/dev/null | grep -q "UP"; then
        print_success "GRE Tunnel created and active!"
        echo ""
        printf "  ${CYAN}%-14s${NC} : ${WHITE}%s${NC}\n" "Interface" "$tun_name"
        printf "  ${CYAN}%-14s${NC} : ${WHITE}%s${NC}\n" "Local WAN"  "$local_ip_gre"
        printf "  ${CYAN}%-14s${NC} : ${WHITE}%s${NC}\n" "Remote WAN" "$remote_ip_gre"
        printf "  ${CYAN}%-14s${NC} : ${WHITE}%s${NC}\n" "Tunnel IP"  "$tun_local/30"
        echo ""
        echo -e "${YELLOW}  Test with: ${NC}${GREEN}ping $tun_remote${NC}"
        echo -e "${YELLOW}  Route traffic through tunnel:${NC}"
        echo -e "  ${DIM}ip route add <dest_network> via $tun_remote${NC}"
    else
        print_error "GRE tunnel creation may have failed"
        ip link show "$tun_name" 2>/dev/null || echo "Interface not found"
    fi
    pause
}

# ═══════════════════════════════════════════════════════════════════════════
# IPSEC TUNNEL CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════

install_strongswan() {
    local os
    os=$(detect_os)
    print_step "Installing StrongSwan (IPsec)..."
    case $os in
        ubuntu|debian)
            apt-get update -qq >/dev/null 2>&1
            apt-get install -y strongswan strongswan-pki libcharon-extra-plugins >/dev/null 2>&1 ;;
        centos|rhel|rocky|almalinux)
            yum install -y epel-release >/dev/null 2>&1
            yum install -y strongswan >/dev/null 2>&1 ;;
        fedora)
            dnf install -y strongswan >/dev/null 2>&1 ;;
        *) print_error "Please install StrongSwan manually"; return 1 ;;
    esac
    command -v ipsec &>/dev/null && print_success "StrongSwan installed" || { print_error "Installation failed"; return 1; }
}

configure_ipsec() {
    clear; show_banner
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  IPsec Tunnel Configuration (StrongSwan)                          ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════╝${NC}\n"

    echo -e "${CYAN}IPsec provides strong encryption for site-to-site tunnels.${NC}"
    echo -e "${CYAN}Requires StrongSwan on both servers.${NC}\n"

    if ! command -v ipsec &>/dev/null; then
        print_warning "StrongSwan not installed. Installing..."
        install_strongswan || { pause; return; }
    fi

    get_network_info
    local public_ip
    public_ip=$(get_public_ip)

    read -r -p "$(echo -e "${YELLOW}[1] Connection Name (e.g: iran-kharej): ${NC}")" conn_name
    conn_name=$(clean_config_name "${conn_name:-tunnel1}")

    read -r -p "$(echo -e "${YELLOW}[2] This Server Public IP: ${NC}")" left_ip
    left_ip="${left_ip:-$public_ip}"

    read -r -p "$(echo -e "${YELLOW}[3] Remote Server Public IP: ${NC}")" right_ip
    [ -z "$right_ip" ] && { print_error "Remote IP required"; return; }

    read -r -p "$(echo -e "${YELLOW}[4] This Tunnel IP (e.g: 192.168.200.1): ${NC}")" left_tun
    left_tun="${left_tun:-192.168.200.1}"

    read -r -p "$(echo -e "${YELLOW}[5] Remote Tunnel IP (e.g: 192.168.200.2): ${NC}")" right_tun
    right_tun="${right_tun:-192.168.200.2}"

    read -r -p "$(echo -e "${YELLOW}[6] Pre-Shared Key (PSK): ${NC}")" psk
    if [ -z "$psk" ]; then
        psk=$(generate_secret_key)
        echo -e "${GREEN}  Auto-generated PSK: $psk${NC}"
    fi

    echo -e "\n${CYAN}[7] IKE Encryption:${NC}"
    echo -e "  ${WHITE}[1]${NC} aes256gcm16-sha256-ecp256  (Modern / Recommended)"
    echo -e "  ${WHITE}[2]${NC} aes256-sha256-modp2048      (Compatible)"
    echo -e "  ${WHITE}[3]${NC} aes128-sha256-modp1024      (Fast)"
    read -r -p "Choose [1-3] (default 1): " ike_choice
    local ike_alg esp_alg
    case "${ike_choice:-1}" in
        2) ike_alg="aes256-sha256-modp2048"; esp_alg="aes256-sha256" ;;
        3) ike_alg="aes128-sha256-modp1024"; esp_alg="aes128-sha256" ;;
        *) ike_alg="aes256gcm16-sha256-ecp256"; esp_alg="aes256gcm16-sha256" ;;
    esac

    mkdir -p "$CONFIG_DIR/ipsec"

    # Write ipsec.conf
    cat > "/etc/ipsec.conf" << EOF
# AVASH IPsec Configuration - ${conn_name}
config setup
    charondebug="ike 1, knl 1, cfg 0"
    uniqueids=no

conn %default
    ikelifetime=60m
    keylife=20m
    rekeymargin=3m
    keyingtries=1
    keyexchange=ikev2
    authby=secret

conn ${conn_name}
    left=${left_ip}
    leftsubnet=${left_tun}/32
    leftid=${left_ip}
    right=${right_ip}
    rightsubnet=${right_tun}/32
    rightid=${right_ip}
    ike=${ike_alg}!
    esp=${esp_alg}!
    auto=start
    type=tunnel
EOF

    # Write PSK
    echo "${left_ip} ${right_ip} : PSK \"${psk}\"" > /etc/ipsec.secrets
    chmod 600 /etc/ipsec.secrets

    # Save config copy
    cp /etc/ipsec.conf "$CONFIG_DIR/ipsec/${conn_name}.conf"
    echo "$psk" > "$CONFIG_DIR/ipsec/${conn_name}.psk"
    chmod 600 "$CONFIG_DIR/ipsec/${conn_name}.psk"

    # Enable IP forwarding
    echo 1 > /proc/sys/net/ipv4/ip_forward
    sed -i '/net.ipv4.ip_forward/d' /etc/sysctl.conf
    echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf

    # Start service
    systemctl enable strongswan >/dev/null 2>&1
    systemctl restart strongswan 2>/dev/null || systemctl restart ipsec 2>/dev/null || ipsec start

    sleep 3
    local ipsec_status
    ipsec_status=$(ipsec status 2>/dev/null || echo "unknown")

    if echo "$ipsec_status" | grep -q "ESTABLISHED\|connecting"; then
        print_success "IPsec tunnel active!"
    else
        print_warning "IPsec started (may need time to establish)"
        echo "$ipsec_status" | head -10
    fi

    echo ""
    printf "  ${CYAN}%-14s${NC} : ${WHITE}%s${NC}\n" "Connection"  "$conn_name"
    printf "  ${CYAN}%-14s${NC} : ${WHITE}%s${NC}\n" "Local IP"    "$left_ip"
    printf "  ${CYAN}%-14s${NC} : ${WHITE}%s${NC}\n" "Remote IP"   "$right_ip"
    printf "  ${CYAN}%-14s${NC} : ${WHITE}%s${NC}\n" "Tunnel IPs"  "$left_tun ↔ $right_tun"
    printf "  ${CYAN}%-14s${NC} : ${WHITE}%s${NC}\n" "IKE"         "$ike_alg"
    echo ""
    echo -e "${YELLOW}  PSK (copy to the other server too):${NC}"
    echo -e "  ${GREEN}${BOLD}$psk${NC}"
    echo ""
    echo -e "${DIM}  Check status: ${NC}${GREEN}ipsec status${NC}"
    pause
}

# ═══════════════════════════════════════════════════════════════════════════
# SIT (6in4) TUNNEL CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════

configure_sit() {
    clear; show_banner
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  SIT / 6in4 Tunnel Configuration (IPv6 over IPv4)                ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════╝${NC}\n"

    echo -e "${CYAN}SIT tunnels encapsulate IPv6 packets inside IPv4.${NC}"
    echo -e "${CYAN}Useful for connecting IPv6 networks over IPv4 infrastructure.${NC}\n"

    get_network_info

    read -r -p "$(echo -e "${YELLOW}[1] Tunnel Name (e.g: sit1): ${NC}")" sit_name
    sit_name=$(clean_config_name "${sit_name:-sit1}")

    read -r -p "$(echo -e "${YELLOW}[2] Local IPv4: ${NC}")" local_ipv4
    local_ipv4="${local_ipv4:-$LOCAL_IP}"

    read -r -p "$(echo -e "${YELLOW}[3] Remote IPv4: ${NC}")" remote_ipv4
    [ -z "$remote_ipv4" ] && { print_error "Remote IP required"; return; }
    validate_ip "$remote_ipv4" || { print_error "Invalid IP"; return; }

    read -r -p "$(echo -e "${YELLOW}[4] Local IPv6 Address (e.g: 2001:db8::1): ${NC}")" local_ipv6
    local_ipv6="${local_ipv6:-2001:db8::1}"

    read -r -p "$(echo -e "${YELLOW}[5] IPv6 Prefix Length (default: 64): ${NC}")" ipv6_prefix
    ipv6_prefix="${ipv6_prefix:-64}"

    read -r -p "$(echo -e "${YELLOW}[6] TTL (default: 64): ${NC}")" sit_ttl
    sit_ttl="${sit_ttl:-64}"

    print_step "Loading SIT kernel module..."
    modprobe sit 2>/dev/null || true

    print_step "Creating SIT tunnel: $sit_name"
    ip tunnel del "$sit_name" 2>/dev/null || true
    ip tunnel add "$sit_name" mode sit \
        local "$local_ipv4" remote "$remote_ipv4" \
        ttl "$sit_ttl"
    ip link set "$sit_name" up
    ip -6 addr add "${local_ipv6}/${ipv6_prefix}" dev "$sit_name"

    mkdir -p "$CONFIG_DIR/sit"
    cat > "$CONFIG_DIR/sit/${sit_name}.conf" << EOF
TUNNEL_NAME="$sit_name"
LOCAL_IPV4="$local_ipv4"
REMOTE_IPV4="$remote_ipv4"
LOCAL_IPV6="$local_ipv6"
IPV6_PREFIX="$ipv6_prefix"
TTL="$sit_ttl"
EOF

    cat > "$SERVICE_DIR/avash-sit-${sit_name}.service" << EOF
[Unit]
Description=AVASH SIT Tunnel - ${sit_name}
After=network.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/bash -c 'modprobe sit; ip tunnel add ${sit_name} mode sit local ${local_ipv4} remote ${remote_ipv4} ttl ${sit_ttl}; ip link set ${sit_name} up; ip -6 addr add ${local_ipv6}/${ipv6_prefix} dev ${sit_name}'
ExecStop=/bin/bash -c 'ip tunnel del ${sit_name}'

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable "avash-sit-${sit_name}" >/dev/null 2>&1

    if ip link show "$sit_name" 2>/dev/null | grep -q "UP"; then
        print_success "SIT Tunnel created!"
        echo ""
        printf "  ${CYAN}%-14s${NC} : ${WHITE}%s${NC}\n" "Interface"  "$sit_name"
        printf "  ${CYAN}%-14s${NC} : ${WHITE}%s${NC}\n" "Local IPv4" "$local_ipv4"
        printf "  ${CYAN}%-14s${NC} : ${WHITE}%s${NC}\n" "Remote IPv4" "$remote_ipv4"
        printf "  ${CYAN}%-14s${NC} : ${WHITE}%s${NC}\n" "IPv6 Addr"  "${local_ipv6}/${ipv6_prefix}"
    else
        print_error "SIT tunnel may have failed"
    fi
    pause
}

# ═══════════════════════════════════════════════════════════════════════════
# IPIP TUNNEL CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════

configure_ipip() {
    clear; show_banner
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  IPIP Tunnel Configuration (IP-in-IP)                             ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════╝${NC}\n"

    echo -e "${CYAN}IPIP encapsulates IPv4 packets inside IPv4. Lightweight and fast.${NC}"
    echo -e "${CYAN}No encryption — best for internal/trusted networks.${NC}\n"

    get_network_info

    read -r -p "$(echo -e "${YELLOW}[1] Tunnel Name (e.g: ipip0): ${NC}")" ipip_name
    ipip_name=$(clean_config_name "${ipip_name:-ipip0}")

    read -r -p "$(echo -e "${YELLOW}[2] Local IP (this server): ${NC}")" ipip_local
    ipip_local="${ipip_local:-$LOCAL_IP}"

    read -r -p "$(echo -e "${YELLOW}[3] Remote IP (other server): ${NC}")" ipip_remote
    [ -z "$ipip_remote" ] && { print_error "Remote IP required"; return; }
    validate_ip "$ipip_remote" || { print_error "Invalid IP"; return; }

    read -r -p "$(echo -e "${YELLOW}[4] Tunnel Local IP (e.g: 10.10.0.1): ${NC}")" tun_local
    tun_local="${tun_local:-10.10.0.1}"

    read -r -p "$(echo -e "${YELLOW}[5] Tunnel Remote IP (e.g: 10.10.0.2): ${NC}")" tun_remote
    tun_remote="${tun_remote:-10.10.0.2}"

    read -r -p "$(echo -e "${YELLOW}[6] TTL (default: 64): ${NC}")" ipip_ttl
    ipip_ttl="${ipip_ttl:-64}"

    print_step "Loading IPIP kernel module..."
    modprobe ipip 2>/dev/null || true

    print_step "Creating IPIP tunnel: $ipip_name"
    ip tunnel del "$ipip_name" 2>/dev/null || true
    ip tunnel add "$ipip_name" mode ipip \
        local "$ipip_local" remote "$ipip_remote" \
        ttl "$ipip_ttl"
    ip link set "$ipip_name" up
    ip addr add "${tun_local}/30" dev "$ipip_name"
    ip link set "$ipip_name" mtu 1480

    mkdir -p "$CONFIG_DIR/ipip"
    cat > "$CONFIG_DIR/ipip/${ipip_name}.conf" << EOF
TUNNEL_NAME="$ipip_name"
LOCAL_IP="$ipip_local"
REMOTE_IP="$ipip_remote"
TUN_LOCAL="$tun_local"
TUN_REMOTE="$tun_remote"
TTL="$ipip_ttl"
EOF

    cat > "$SERVICE_DIR/avash-ipip-${ipip_name}.service" << EOF
[Unit]
Description=AVASH IPIP Tunnel - ${ipip_name}
After=network.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/bash -c 'modprobe ipip; ip tunnel add ${ipip_name} mode ipip local ${ipip_local} remote ${ipip_remote} ttl ${ipip_ttl}; ip link set ${ipip_name} up; ip addr add ${tun_local}/30 dev ${ipip_name}; ip link set ${ipip_name} mtu 1480'
ExecStop=/bin/bash -c 'ip tunnel del ${ipip_name}'

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable "avash-ipip-${ipip_name}" >/dev/null 2>&1

    if ip link show "$ipip_name" 2>/dev/null | grep -q "UP"; then
        print_success "IPIP Tunnel created!"
        echo ""
        printf "  ${CYAN}%-14s${NC} : ${WHITE}%s${NC}\n" "Interface"  "$ipip_name"
        printf "  ${CYAN}%-14s${NC} : ${WHITE}%s${NC}\n" "WAN Local"  "$ipip_local"
        printf "  ${CYAN}%-14s${NC} : ${WHITE}%s${NC}\n" "WAN Remote" "$ipip_remote"
        printf "  ${CYAN}%-14s${NC} : ${WHITE}%s${NC}\n" "Tunnel IP"  "$tun_local/30"
        echo ""
        echo -e "${YELLOW}  Test with: ${NC}${GREEN}ping $tun_remote${NC}"
    else
        print_error "IPIP tunnel creation may have failed"
    fi
    pause
}

# ═══════════════════════════════════════════════════════════════════════════
# PROTOCOL SELECTION MENU (Server/Client)
# ═══════════════════════════════════════════════════════════════════════════

configure_server() {
    while true; do
        clear; show_banner
        echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║  Configure Server (Abroad/Kharej)                                 ║${NC}"
        echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════╝${NC}\n"

        echo -e "${CYAN}Select Tunnel Protocol:${NC}\n"
        echo -e "  ${WHITE}[1]${NC} 🚀 KCP       - Raw packet tunnel (anti-censorship, high-perf)"
        echo -e "  ${WHITE}[2]${NC} 🔒 WireGuard - Modern VPN (fastest, encrypted)"
        echo -e "  ${WHITE}[3]${NC} 🌐 GRE       - Generic routing encapsulation (fast, unencrypted)"
        echo -e "  ${WHITE}[4]${NC} 🛡️  IPsec     - Encrypted site-to-site (most secure)"
        echo -e "  ${WHITE}[5]${NC} 📡 SIT/6in4  - IPv6 over IPv4 tunnel"
        echo -e "  ${WHITE}[6]${NC} ⚡ IPIP      - IP-in-IP encapsulation (lightest)"
        echo -e "  ${WHITE}[0]${NC} ↩️  Back"
        echo ""

        read -r -p "Choose protocol [0-6]: " proto_choice
        case "$proto_choice" in
            1) configure_kcp_server ;;
            2) configure_wireguard_server ;;
            3) configure_gre ;;
            4) configure_ipsec ;;
            5) configure_sit ;;
            6) configure_ipip ;;
            0) return ;;
            *) print_error "Invalid choice"; sleep 1 ;;
        esac
    done
}

configure_client() {
    while true; do
        clear; show_banner
        echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║  Configure Client (Iran/Domestic)                                 ║${NC}"
        echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════╝${NC}\n"

        echo -e "${CYAN}Select Tunnel Protocol:${NC}\n"
        echo -e "  ${WHITE}[1]${NC} 🚀 KCP       - Raw packet client (port forward / SOCKS5)"
        echo -e "  ${WHITE}[2]${NC} 🔒 WireGuard - WireGuard client"
        echo -e "  ${WHITE}[3]${NC} 🌐 GRE       - GRE tunnel (same as server-side)"
        echo -e "  ${WHITE}[4]${NC} 🛡️  IPsec     - IPsec client tunnel"
        echo -e "  ${WHITE}[5]${NC} 📡 SIT/6in4  - SIT tunnel client"
        echo -e "  ${WHITE}[6]${NC} ⚡ IPIP      - IPIP tunnel client"
        echo -e "  ${WHITE}[0]${NC} ↩️  Back"
        echo ""

        read -r -p "Choose protocol [0-6]: " proto_choice
        case "$proto_choice" in
            1) configure_kcp_client ;;
            2) configure_wireguard_client ;;
            3) configure_gre ;;
            4) configure_ipsec ;;
            5) configure_sit ;;
            6) configure_ipip ;;
            0) return ;;
            *) print_error "Invalid choice"; sleep 1 ;;
        esac
    done
}

# ═══════════════════════════════════════════════════════════════════════════
# SERVICE MANAGEMENT
# ═══════════════════════════════════════════════════════════════════════════

get_all_avash_services() {
    systemctl list-unit-files --type=service --no-legend --no-pager 2>/dev/null \
        | grep -E '^avash-.*\.service' | awk '{print $1}' || true
}

manage_services() {
    while true; do
        clear; show_banner
        echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║  Service Manager                                                   ║${NC}"
        echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════╝${NC}\n"

        local services=()
        mapfile -t services < <(get_all_avash_services)

        if [ ${#services[@]} -eq 0 ]; then
            echo -e "${YELLOW}  No AVASH tunnel services found.${NC}\n"
            pause; return
        fi

        echo -e "${CYAN}┌─────┬──────────────────────────────────┬────────────┬──────────────┐${NC}"
        echo -e "${CYAN}│  #  │ Service                          │ Status     │ Auto-Restart │${NC}"
        echo -e "${CYAN}├─────┼──────────────────────────────────┼────────────┼──────────────┤${NC}"

        local i=1
        for svc in "${services[@]}"; do
            local status
            status=$(systemctl is-active "$svc" 2>/dev/null || echo "unknown")
            local cron_status="No"
            crontab -l 2>/dev/null | grep -q "systemctl restart ${svc%.service}" && cron_status="Yes"

            local scolor
            case "$status" in
                active)   scolor="${GREEN}"  ;;
                failed)   scolor="${RED}"    ;;
                inactive) scolor="${YELLOW}" ;;
                *)        scolor="${WHITE}"  ;;
            esac

            printf "${CYAN}│${NC} %3d ${CYAN}│${NC} %-32s ${CYAN}│${NC} ${scolor}%-10s${NC} ${CYAN}│${NC} %-12s ${CYAN}│${NC}\n" \
                "$i" "${svc%.service}" "$status" "$cron_status"
            ((i++))
        done
        echo -e "${CYAN}└─────┴──────────────────────────────────┴────────────┴──────────────┘${NC}\n"

        echo -e "${YELLOW}Options:${NC}  0=Back  1-${#services[@]}=Manage service"
        echo ""
        read -r -p "Choose [0-${#services[@]}]: " choice

        [ "$choice" = "0" ] && return
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#services[@]} ]; then
            manage_single_service "${services[$((choice-1))]}"
        else
            print_error "Invalid choice"; sleep 1
        fi
    done
}

manage_single_service() {
    local svc="$1"
    local name="${svc%.service}"

    while true; do
        clear; show_banner
        echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════╗${NC}"
        printf "${GREEN}║  Managing: %-54s║${NC}\n" "$name "
        echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════╝${NC}\n"

        local status
        status=$(systemctl is-active "$svc" 2>/dev/null || echo "unknown")
        case "$status" in
            active)   echo -e "  Status: ${GREEN}🟢 Running${NC}" ;;
            failed)   echo -e "  Status: ${RED}🔴 Failed${NC}"  ;;
            inactive) echo -e "  Status: ${YELLOW}🟡 Stopped${NC}" ;;
            *)        echo -e "  Status: ${WHITE}⚪ Unknown${NC}" ;;
        esac

        echo ""
        echo -e "${CYAN}  Cronjob:${NC}"
        echo "  $(view_cronjob "${svc%.service}")"
        echo ""
        echo -e "  ${WHITE}[1]${NC} 🟢 Start"
        echo -e "  ${WHITE}[2]${NC} 🔴 Stop"
        echo -e "  ${WHITE}[3]${NC} 🔄 Restart"
        echo -e "  ${WHITE}[4]${NC} 📊 Status details"
        echo -e "  ${WHITE}[5]${NC} 📝 View logs (last 40 lines)"
        echo -e "  ${WHITE}[6]${NC} ⏰ Manage auto-restart"
        echo -e "  ${WHITE}[7]${NC} 🗑️  Delete service"
        echo -e "  ${WHITE}[0]${NC} ↩️  Back"
        echo ""

        read -r -p "Choose [0-7]: " action
        case "$action" in
            1) systemctl start "$svc" && print_success "Started" || print_error "Failed"; sleep 1.5 ;;
            2) systemctl stop  "$svc" && print_success "Stopped" || print_error "Failed"; sleep 1.5 ;;
            3) systemctl restart "$svc" && print_success "Restarted" || print_error "Failed"; sleep 1.5 ;;
            4) systemctl status "$svc" --no-pager -l; pause ;;
            5) journalctl -u "$svc" -n 40 --no-pager; pause ;;
            6) manage_cronjob_menu "${svc%.service}" ;;
            7) delete_service "$svc"; pause; return ;;
            0) return ;;
            *) print_error "Invalid"; sleep 1 ;;
        esac
    done
}

manage_cronjob_menu() {
    local svc_name="$1"
    while true; do
        clear; show_banner
        echo -e "${YELLOW}Auto-Restart Configuration: $svc_name${NC}\n"
        echo -e "${CYAN}Current:${NC}"
        echo "  $(view_cronjob "$svc_name")"
        echo ""
        echo -e "${CYAN}Set auto-restart interval:${NC}"
        local i=1
        for interval in "${!RESTART_INTERVALS[@]}"; do
            echo "  [$i] Every $interval"
            ((i++))
        done
        echo "  [$i] Remove cronjob"
        echo "  [0] Back"
        echo ""
        read -r -p "Choose: " cron_choice
        [ "$cron_choice" = "0" ] && return

        if [ "$cron_choice" = "$i" ]; then
            remove_cronjob "$svc_name"; pause; return
        elif [[ "$cron_choice" =~ ^[0-9]+$ ]] && [ "$cron_choice" -ge 1 ] && [ "$cron_choice" -lt "$i" ]; then
            local idx=1
            for interval in "${!RESTART_INTERVALS[@]}"; do
                if [ "$cron_choice" = "$idx" ]; then
                    add_cronjob "$svc_name" "$interval"; pause; return
                fi
                ((idx++))
            done
        else
            print_error "Invalid choice"; sleep 1
        fi
    done
}

delete_service() {
    local svc="$1"
    local name="${svc%.service}"
    read -r -p "$(echo -e "${RED}Delete $name? This cannot be undone. (y/N): ${NC}")" confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        remove_cronjob "$name" 2>/dev/null || true
        systemctl stop    "$svc" 2>/dev/null || true
        systemctl disable "$svc" 2>/dev/null || true
        rm -f "$SERVICE_DIR/$svc"
        systemctl daemon-reload 2>/dev/null || true
        print_success "Service deleted: $name"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════
# INSTALLATION & DEPENDENCIES
# ═══════════════════════════════════════════════════════════════════════════

install_dependencies() {
    clear; show_banner
    print_step "Installing base dependencies...\n"
    local os
    os=$(detect_os)

    case $os in
        ubuntu|debian)
            apt-get update -qq >/dev/null 2>&1
            DEBIAN_FRONTEND=noninteractive apt-get install -y \
                curl wget iptables iptables-persistent netfilter-persistent \
                lsof iproute2 cron dnsutils libpcap-dev \
                net-tools tcpdump >/dev/null 2>&1
            ;;
        centos|rhel|rocky|almalinux)
            yum install -y curl wget iptables-services lsof \
                iproute cronie bind-utils libpcap-devel \
                net-tools tcpdump >/dev/null 2>&1
            systemctl enable iptables >/dev/null 2>&1
            ;;
        fedora)
            dnf install -y curl wget iptables lsof iproute \
                cronie bind-utils libpcap-devel >/dev/null 2>&1
            ;;
        *)
            print_warning "Unknown OS — install manually: curl wget iptables lsof iproute2"
            ;;
    esac

    # Enable IP forwarding globally
    echo "net.ipv4.ip_forward = 1"     >> /etc/sysctl.conf
    echo "net.core.rmem_max = 67108864" >> /etc/sysctl.conf
    echo "net.core.wmem_max = 67108864" >> /etc/sysctl.conf
    sysctl -p >/dev/null 2>&1

    mkdir -p "$CONFIG_DIR" "$LOG_DIR" "$BACKUP_DIR"
    print_success "Dependencies installed!"
    pause
}

install_manager() {
    print_step "Installing AVASH Tunnel Manager to $MANAGER_PATH..."
    cp -f "$0" "$MANAGER_PATH" 2>/dev/null || cp -f "${BASH_SOURCE[0]}" "$MANAGER_PATH"
    chmod +x "$MANAGER_PATH"
    print_success "Manager installed! Run: ${GREEN}avash-tunnel${NC}"
}

# ═══════════════════════════════════════════════════════════════════════════
# SERVER OPTIMIZATION
# ═══════════════════════════════════════════════════════════════════════════

optimize_server() {
    clear; show_banner
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  Server Optimization                                               ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════╝${NC}\n"

    print_step "Applying kernel optimization settings..."

    mkdir -p "$BACKUP_DIR"
    cp /etc/sysctl.conf "$BACKUP_DIR/sysctl-$(date +%Y%m%d-%H%M%S).bak" 2>/dev/null || true

    cat > /etc/sysctl.d/99-avash-tunnel.conf << 'EOF'
# AVASH Tunnel Optimization
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1

# Socket buffers
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
net.core.rmem_default = 1048576
net.core.wmem_default = 1048576
net.core.optmem_max = 65536
net.core.netdev_max_backlog = 65536

# TCP optimization
net.ipv4.tcp_rmem = 4096 1048576 33554432
net.ipv4.tcp_wmem = 4096 524288 16777216
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_mtu_probing = 1

# UDP optimization (for KCP/WireGuard)
net.ipv4.udp_rmem_min = 8192
net.ipv4.udp_wmem_min = 8192

# Connection tracking
net.nf_conntrack_max = 1048576
net.netfilter.nf_conntrack_max = 1048576
net.netfilter.nf_conntrack_tcp_timeout_time_wait = 30
net.netfilter.nf_conntrack_tcp_timeout_established = 7440

# File descriptors
fs.file-max = 1048576
fs.nr_open  = 1048576
EOF

    sysctl -p /etc/sysctl.d/99-avash-tunnel.conf >/dev/null 2>&1

    # Enable BBR
    if ! lsmod | grep -q tcp_bbr; then
        modprobe tcp_bbr 2>/dev/null || true
        echo "tcp_bbr" >> /etc/modules-load.d/modules.conf 2>/dev/null || true
    fi

    # File descriptor limits
    cat > /etc/security/limits.d/99-avash.conf << 'EOF'
*    soft nofile 1048576
*    hard nofile 1048576
root soft nofile 1048576
root hard nofile 1048576
EOF

    print_success "Kernel optimizations applied!"
    echo ""
    echo -e "  ${GREEN}✓${NC} TCP BBR congestion control enabled"
    echo -e "  ${GREEN}✓${NC} Socket buffers optimized (64MB)"
    echo -e "  ${GREEN}✓${NC} IP forwarding enabled"
    echo -e "  ${GREEN}✓${NC} Connection tracking optimized"
    echo -e "  ${GREEN}✓${NC} File descriptor limits increased"
    echo -e "  ${GREEN}✓${NC} TCP FastOpen enabled"
    echo -e "  ${GREEN}✓${NC} UDP buffers optimized for KCP/WireGuard"
    pause
}

# ═══════════════════════════════════════════════════════════════════════════
# CONNECTION TESTING
# ═══════════════════════════════════════════════════════════════════════════

test_connection() {
    while true; do
        clear; show_banner
        echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║  Connection Testing                                                ║${NC}"
        echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════╝${NC}\n"

        echo -e "  ${WHITE}[1]${NC} 🔁 Ping + MTU Test (to remote server)"
        echo -e "  ${WHITE}[2]${NC} 🌐 Internet Connectivity"
        echo -e "  ${WHITE}[3]${NC} 🧭 DNS Resolution Test"
        echo -e "  ${WHITE}[4]${NC} 📊 All Tunnel Status"
        echo -e "  ${WHITE}[0]${NC} ↩️  Back"
        echo ""
        read -r -p "Choose [0-4]: " tc

        case "$tc" in
            1) test_ping_mtu ;;
            2) test_internet ;;
            3) test_dns ;;
            4) test_all_tunnels ;;
            0) return ;;
            *) print_error "Invalid"; sleep 1 ;;
        esac
    done
}

test_ping_mtu() {
    read -r -p "$(echo -e "${YELLOW}Remote Server IP: ${NC}")" rip
    [ -z "$rip" ] && return
    validate_ip "$rip" || { print_error "Invalid IP"; pause; return; }

    echo -e "\n${CYAN}Ping Test to $rip:${NC}"
    local result
    result=$(ping -c 5 -W 2 "$rip" 2>&1)
    if echo "$result" | grep -q "transmitted"; then
        local loss avg
        loss=$(echo "$result" | grep -o '[0-9]*% packet loss' | grep -o '[0-9]*')
        avg=$(echo "$result"  | grep rtt | awk -F'/' '{print $5}')
        echo -e "  Packet Loss : ${loss:-?}%"
        echo -e "  Avg RTT     : ${avg:-?} ms"
        [ "${loss:-100}" -le 5  ] && echo -e "  ${GREEN}✅ Connection quality: EXCELLENT${NC}"
        [ "${loss:-100}" -gt 5  ] && [ "${loss:-100}" -le 20 ] && echo -e "  ${YELLOW}⚠️  Connection quality: FAIR${NC}"
        [ "${loss:-100}" -gt 20 ] && echo -e "  ${RED}❌ Connection quality: POOR${NC}"
    else
        echo -e "  ${RED}❌ Ping failed${NC}"
    fi

    echo -e "\n${CYAN}MTU Discovery Test:${NC}"
    local best_mtu="Unknown"
    for mtu in "${MTU_TESTS[@]}"; do
        local ps=$((mtu - 28))
        [ $ps -lt 0 ] && continue
        printf "  MTU %4s: " "$mtu"
        local pr
        pr=$(ping -c 3 -W 1 -M do -s "$ps" "$rip" 2>&1)
        if echo "$pr" | grep -q "3 received\|3 packets received"; then
            echo -e "${GREEN}OK${NC}"
            best_mtu="$mtu"
            break
        elif echo "$pr" | grep -q "transmitted"; then
            local r
            r=$(echo "$pr" | grep transmitted | awk '{print $4}')
            [ "${r:-0}" -gt 0 ] && { echo -e "${YELLOW}PARTIAL (${r}/3)${NC}"; best_mtu="$mtu"; } || echo -e "${RED}FAIL${NC}"
        else
            echo -e "${RED}FAIL${NC}"
        fi
    done
    echo -e "\n  ${GREEN}Recommended MTU: $best_mtu${NC}"
    pause
}

test_internet() {
    echo -e "\n${CYAN}Internet Connectivity Test:${NC}\n"
    local ok=0
    for svc in "https://google.com" "https://github.com" "https://cloudflare.com"; do
        printf "  %-30s: " "$svc"
        if curl -s --max-time 4 "$svc" >/dev/null 2>&1; then
            echo -e "${GREEN}✅ OK${NC}"; ((ok++))
        else
            echo -e "${RED}❌ Failed${NC}"
        fi
    done
    echo ""
    [ "$ok" -ge 2 ] && print_success "Internet: Working" || print_error "Internet: Limited/Blocked"
    pause
}

test_dns() {
    echo -e "\n${CYAN}DNS Resolution Test:${NC}\n"
    for dns in "${DNS_SERVERS[@]}"; do
        printf "  DNS %-15s: " "$dns"
        if timeout 3 dig +short google.com "@$dns" >/dev/null 2>&1; then
            echo -e "${GREEN}✅ Working${NC}"
        else
            echo -e "${RED}❌ Failed${NC}"
        fi
    done
    echo ""
    printf "  %-20s: " "System DNS"
    if timeout 3 nslookup google.com >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Working${NC}"
    else
        echo -e "${RED}❌ Failed${NC}"
    fi
    pause
}

test_all_tunnels() {
    echo -e "\n${CYAN}Active Tunnel Interfaces:${NC}\n"
    # WireGuard
    if command -v wg &>/dev/null; then
        local wg_ifaces
        wg_ifaces=$(wg show interfaces 2>/dev/null)
        if [ -n "$wg_ifaces" ]; then
            echo -e "${GREEN}WireGuard:${NC}"
            wg show 2>/dev/null | grep -E "interface|endpoint|transfer|latest"
            echo ""
        fi
    fi
    # GRE / IPIP / SIT
    echo -e "${GREEN}Kernel Tunnels:${NC}"
    ip tunnel show 2>/dev/null | grep -v "any/any" || echo "  None"
    echo ""
    # IPsec
    if command -v ipsec &>/dev/null; then
        echo -e "${GREEN}IPsec:${NC}"
        ipsec status 2>/dev/null | head -10 || echo "  Not running"
    fi
    # AVASH services
    echo -e "\n${GREEN}AVASH Services:${NC}"
    for svc in $(get_all_avash_services); do
        local st
        st=$(systemctl is-active "$svc" 2>/dev/null)
        local col
        [ "$st" = "active" ] && col="$GREEN" || col="$RED"
        printf "  %-40s ${col}%s${NC}\n" "${svc%.service}" "$st"
    done
    pause
}

# ═══════════════════════════════════════════════════════════════════════════
# UNINSTALL
# ═══════════════════════════════════════════════════════════════════════════

uninstall_all() {
    clear; show_banner
    echo -e "${RED}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║  Uninstall AVASH Tunnel Manager                                    ║${NC}"
    echo -e "${RED}╚══════════════════════════════════════════════════════════════════╝${NC}\n"

    echo -e "${YELLOW}This will:${NC}"
    echo -e "  • Stop and remove ALL tunnel services"
    echo -e "  • Delete configs in $CONFIG_DIR"
    echo -e "  • Remove iptables rules"
    echo -e "  • Remove $MANAGER_PATH"
    echo ""
    read -r -p "$(echo -e "${RED}Are you SURE? Type 'yes' to confirm: ${NC}")" confirm

    [ "$confirm" != "yes" ] && { print_info "Cancelled"; pause; return; }

    print_step "Stopping and removing all services..."
    for svc in $(get_all_avash_services); do
        remove_cronjob "${svc%.service}" 2>/dev/null || true
        systemctl stop    "$svc" 2>/dev/null || true
        systemctl disable "$svc" 2>/dev/null || true
        rm -f "$SERVICE_DIR/$svc"
    done
    systemctl daemon-reload 2>/dev/null || true

    print_step "Removing WireGuard interfaces..."
    if command -v wg &>/dev/null; then
        for iface in $(wg show interfaces 2>/dev/null); do
            wg-quick down "$iface" 2>/dev/null || true
        done
    fi

    print_step "Removing kernel tunnels..."
    ip tunnel show 2>/dev/null | awk -F: '{print $1}' | while read -r t; do
        [[ "$t" =~ ^(gre|ipip|sit)[0-9] ]] && ip tunnel del "$t" 2>/dev/null || true
    done

    print_step "Removing configs..."
    rm -rf "$CONFIG_DIR" "$LOG_DIR"
    rm -f "$MANAGER_PATH"
    rm -f /etc/sysctl.d/99-avash-tunnel.conf
    rm -f /etc/security/limits.d/99-avash.conf

    print_success "AVASH Tunnel Manager uninstalled!"
    pause
    exit 0
}

# ═══════════════════════════════════════════════════════════════════════════
# TELEGRAM BOT (simple notification)
# ═══════════════════════════════════════════════════════════════════════════

load_bot_config() {
    BOT_TOKEN="" CHAT_ID="" ENABLE_BOT="false"
    [ -f "$BOT_CONFIG_FILE" ] && . "$BOT_CONFIG_FILE"
}

save_bot_config_file() {
    mkdir -p "$CONFIG_DIR"
    cat > "$BOT_CONFIG_FILE" << EOF
BOT_TOKEN="$BOT_TOKEN"
CHAT_ID="$CHAT_ID"
ENABLE_BOT="$ENABLE_BOT"
EOF
    chmod 600 "$BOT_CONFIG_FILE"
}

send_telegram() {
    local msg="$1"
    [ -z "$BOT_TOKEN" ] || [ -z "$CHAT_ID" ] && return 1
    curl -s --max-time 10 \
        -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        -d "chat_id=${CHAT_ID}&text=${msg}&parse_mode=HTML" >/dev/null 2>&1
}

telegram_bot_menu() {
    load_bot_config
    while true; do
        clear; show_banner
        echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║  Telegram Bot                                                      ║${NC}"
        echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════╝${NC}\n"

        echo -e "  Status  : $( [ "$ENABLE_BOT" = "true" ] && echo "${GREEN}✅ Enabled${NC}" || echo "${RED}❌ Disabled${NC}")"
        echo -e "  Token   : ${CYAN}${BOT_TOKEN:0:20}${BOT_TOKEN:+...}${NC}"
        echo -e "  Chat ID : ${CYAN}${CHAT_ID:-Not set}${NC}"
        echo ""
        echo -e "  ${WHITE}[1]${NC} Setup Bot (token + chat ID)"
        echo -e "  ${WHITE}[2]${NC} Enable/Disable Bot"
        echo -e "  ${WHITE}[3]${NC} Send test message"
        echo -e "  ${WHITE}[0]${NC} ↩️  Back"
        echo ""
        read -r -p "Choose [0-3]: " bc

        case "$bc" in
            1)
                read -r -p "$(echo -e "${YELLOW}Bot Token: ${NC}")" BOT_TOKEN
                read -r -p "$(echo -e "${YELLOW}Chat ID  : ${NC}")" CHAT_ID
                ENABLE_BOT="true"
                save_bot_config_file
                print_success "Bot configured!"
                sleep 1
                ;;
            2)
                [ "$ENABLE_BOT" = "true" ] && ENABLE_BOT="false" || ENABLE_BOT="true"
                save_bot_config_file
                print_success "Bot: $([ "$ENABLE_BOT" = "true" ] && echo "Enabled" || echo "Disabled")"
                sleep 1
                ;;
            3)
                if [ -n "$BOT_TOKEN" ] && [ -n "$CHAT_ID" ]; then
                    local hostname_val
                    hostname_val=$(hostname 2>/dev/null || echo "server")
                    local pub_ip
                    pub_ip=$(get_public_ip)
                    local test_msg="✅ <b>AVASH Tunnel Bot</b>%0A%0ATest message from ${hostname_val}%0AIP: ${pub_ip}%0ATime: $(date '+%Y-%m-%d %H:%M:%S')"
                    if send_telegram "$test_msg"; then
                        print_success "Test message sent!"
                    else
                        print_error "Failed to send. Check token and chat ID."
                    fi
                else
                    print_error "Configure bot first (option 1)"
                fi
                pause
                ;;
            0) return ;;
            *) print_error "Invalid"; sleep 1 ;;
        esac
    done
}

# ═══════════════════════════════════════════════════════════════════════════
# MAIN MENU
# ═══════════════════════════════════════════════════════════════════════════

main_menu() {
    while true; do
        clear
        show_banner

        # Status summary
        local svc_count active_count
        svc_count=$(get_all_avash_services | wc -l)
        active_count=$(get_all_avash_services | while read -r s; do systemctl is-active "$s" 2>/dev/null; done | grep -c "^active" || true)

        echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║  Main Menu                                                         ║${NC}"
        echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════╝${NC}\n"

        # Tunnel status
        if [ "$svc_count" -gt 0 ]; then
            echo -e "  ${GREEN}✅ Active tunnels: ${active_count}/${svc_count}${NC}"
        else
            echo -e "  ${YELLOW}⚠️  No tunnels configured${NC}"
        fi
        echo ""

        echo -e "  ${WHITE}[0]${NC} ⚙️  Install Dependencies & Manager"
        echo -e "  ${WHITE}[1]${NC} 🖥️  Configure Server (Abroad/Kharej)"
        echo -e "  ${WHITE}[2]${NC} 🇮🇷 Configure Client (Iran/Domestic)"
        echo -e "  ${WHITE}[3]${NC} 🛠️  Manage Tunnel Services"
        echo -e "  ${WHITE}[4]${NC} 📊 Test Connection"
        echo -e "  ${WHITE}[5]${NC} 🚀 Optimize Server"
        echo -e "  ${WHITE}[6]${NC} 🤖 Telegram Bot"
        echo -e "  ${WHITE}[7]${NC} 🗑️  Uninstall All"
        echo -e "  ${WHITE}[8]${NC} 🚪 Exit"
        echo ""

        read -r -p "Select option [0-8]: " choice

        case "$choice" in
            0) install_dependencies; install_manager ;;
            1) configure_server ;;
            2) configure_client ;;
            3) manage_services ;;
            4) test_connection ;;
            5) optimize_server ;;
            6) telegram_bot_menu ;;
            7) uninstall_all ;;
            8)
                echo -e "\n${GREEN}══════════════════════════════════════════════════════════════════${NC}"
                echo -e "${GREEN}  Goodbye! — Telegram: ${TELEGRAM_CHANNEL}  ${NC}"
                echo -e "${GREEN}══════════════════════════════════════════════════════════════════${NC}\n"
                exit 0
                ;;
            *) print_error "Invalid option"; sleep 1 ;;
        esac
    done
}

# ─── Start ────────────────────────────────────────────────────────────────
check_root
mkdir -p "$CONFIG_DIR" "$LOG_DIR" "$BACKUP_DIR" 2>/dev/null || true
main_menu
