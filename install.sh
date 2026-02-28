#!/bin/bash
# =============================================================================
#  AVASH Tunnel Manager — v1.0
#  Multi-Protocol Tunnel: KCP • WireGuard • GRE • IPsec • SIT • IPIP
#  Telegram : https://t.me/AVASH_NET
# =============================================================================

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
DIM='\033[2m'
BOLD='\033[1m'
NC='\033[0m'

# ── Constants ─────────────────────────────────────────────────────────────────
SCRIPT_VERSION="1.0"
MANAGER_NAME="avash-tunnel"
MANAGER_PATH="/usr/local/bin/${MANAGER_NAME}"
CONFIG_DIR="/etc/avash-tunnel"
SERVICE_DIR="/etc/systemd/system"
BIN_DIR="/usr/local/bin"
BACKUP_DIR="/root/avash-backups"
LOG_DIR="/var/log/avash-tunnel"
TELEGRAM_CHANNEL="@AVASH_NET"

# ── Paqet Sources ─────────────────────────────────────────────────────────────
PAQET_REPO="hanselime/paqet"
PAQET_VER="v2.2.0-optimize"
PAQET_AMD64="https://github.com/erfanesmizadh/packet/releases/download/paget/paqet-linux-amd64-v2.2.0-optimize.tar.gz"
PAQET_ARM64="https://github.com/erfanesmizadh/packet/releases/download/paget/paqet_linux_arm64-v2.2.0-optimize.tar.gz"

# ── Defaults ──────────────────────────────────────────────────────────────────
DEFAULT_PORT="8888"
DEFAULT_WG_PORT="51820"
DEFAULT_CONNECTIONS="4"
DEFAULT_MTU="1350"
DEFAULT_AUTO_RESTART="1hour"

# ── KCP Modes ─────────────────────────────────────────────────────────────────
declare -A KCP_MODES=(
    ["0"]="normal:Normal speed, normal latency, low CPU"
    ["1"]="fast:Balanced speed, low latency, normal CPU"
    ["2"]="fast2:High speed, lower latency, medium CPU"
    ["3"]="fast3:Max speed, very low latency, high CPU"
    ["4"]="manual:Advanced manual parameters"
)

# ── Encryption Options ────────────────────────────────────────────────────────
declare -A ENCRYPTIONS=(
    ["1"]="aes-128-gcm:Very high security, fastest (Recommended)"
    ["2"]="aes-256-gcm:Maximum security, slower"
    ["3"]="aes-128-cfb:High security, fast"
    ["4"]="chacha20:Modern cipher, low CPU usage"
    ["5"]="none:No encryption, maximum speed (Insecure)"
)

# ── Cron Intervals ────────────────────────────────────────────────────────────
declare -A CRON_INTERVALS=(
    ["5min"]="*/5 * * * *"
    ["15min"]="*/15 * * * *"
    ["30min"]="*/30 * * * *"
    ["1hour"]="0 */1 * * *"
    ["6hour"]="0 */6 * * *"
    ["12hour"]="0 */12 * * *"
    ["1day"]="0 0 * * *"
)

IP_SERVICES=("ifconfig.me" "icanhazip.com" "api.ipify.org" "checkip.amazonaws.com")
MTU_SIZES=("1500" "1470" "1400" "1350" "1300" "1200" "1100" "1000")
DNS_LIST=("8.8.8.8" "1.1.1.1" "208.67.222.222")

# =============================================================================
# PRINT HELPERS
# =============================================================================

p_step() { echo -e "${BLUE}[*]${NC} $1"; }
p_ok()   { echo -e "${GREEN}[+]${NC} $1"; }
p_err()  { echo -e "${RED}[-]${NC} $1"; }
p_warn() { echo -e "${YELLOW}[!]${NC} $1"; }
p_info() { echo -e "${CYAN}[i]${NC} $1"; }

pause() {
    echo ""
    read -r -p "${1:-  Press Enter to continue...}"
}

line() {
    echo -e "${YELLOW}  ──────────────────────────────────────────────────────────────${NC}"
}

box() {
    echo -e "${GREEN}  ╔══════════════════════════════════════════════════════════════╗${NC}"
    printf "${GREEN}  ║  %-60s║${NC}\n" "$1"
    echo -e "${GREEN}  ╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# =============================================================================
# BANNER
# =============================================================================

show_banner() {
    clear
    echo -e "${MAGENTA}"
    echo "  ╔════════════════════════════════════════════════════════════════╗"
    echo "  ║                                                                ║"
    echo "  ║   ██████╗ ██╗   ██╗ █████╗ ███████╗██╗  ██╗                  ║"
    echo "  ║  ██╔═══██╗██║   ██║██╔══██╗██╔════╝██║  ██║                  ║"
    echo "  ║  ███████║ ██║   ██║███████║███████╗███████║                  ║"
    echo "  ║  ██╔══██║  ██╗ ██╔╝██╔══██║╚════██║██╔══██║                  ║"
    echo "  ║  ██║  ██║   ████╔╝ ██║  ██║███████║██║  ██║                  ║"
    echo "  ║  ╚═╝  ╚═╝   ╚═══╝  ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝                  ║"
    echo "  ║                                                                ║"
    echo "  ║      Multi-Protocol Tunnel Manager  v${SCRIPT_VERSION}                 ║"
    echo "  ║      KCP  •  WireGuard  •  GRE  •  IPsec  •  SIT  •  IPIP   ║"
    echo "  ║                                                                ║"
    echo "  ║               📢  Telegram: ${TELEGRAM_CHANNEL}                      ║"
    echo "  ║                                                                ║"
    echo "  ╚════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# =============================================================================
# SYSTEM HELPERS
# =============================================================================

check_root() {
    [[ $EUID -ne 0 ]] && {
        echo -e "${RED}[!] This script must be run as root.${NC}"
        echo -e "    Run: ${YELLOW}sudo bash $0${NC}"
        exit 1
    }
}

detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$ID"
        return
    fi
    [ -f /etc/redhat-release ] && echo "rhel" && return
    uname -s | tr '[:upper:]' '[:lower:]'
}

detect_arch() {
    case "$(uname -m)" in
        x86_64|amd64)  echo "amd64" ;;
        aarch64|arm64) echo "arm64" ;;
        armv7l|armhf)  echo "armv7" ;;
        i386|i686)     echo "386"   ;;
        *)
            p_err "Unsupported architecture: $(uname -m)"
            return 1
            ;;
    esac
}

get_public_ip() {
    local ip
    for svc in "${IP_SERVICES[@]}"; do
        ip=$(curl -4 -s --max-time 3 "$svc" 2>/dev/null)
        [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] && echo "$ip" && return 0
    done
    hostname -I 2>/dev/null | awk '{print $1}' || echo "Unknown"
}

get_network_info() {
    NETWORK_INTERFACE="" LOCAL_IP="" GATEWAY_IP="" GATEWAY_MAC=""
    if command -v ip &>/dev/null; then
        NETWORK_INTERFACE=$(ip route 2>/dev/null | awk '/default/{print $5; exit}')
        LOCAL_IP=$(ip -4 addr show "$NETWORK_INTERFACE" 2>/dev/null \
            | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)
        GATEWAY_IP=$(ip route 2>/dev/null | awk '/default/{print $3; exit}')
        if [ -n "$GATEWAY_IP" ]; then
            ping -c 1 -W 1 "$GATEWAY_IP" >/dev/null 2>&1 || true
            GATEWAY_MAC=$(ip neigh show "$GATEWAY_IP" 2>/dev/null \
                | grep -oE '([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}' | head -1)
        fi
    fi
    NETWORK_INTERFACE="${NETWORK_INTERFACE:-eth0}"
    LOCAL_IP="${LOCAL_IP:-127.0.0.1}"
}

validate_ip() {
    [[ "$1" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1
    local IFS='.'
    read -ra o <<< "$1"
    for x in "${o[@]}"; do [ "$x" -gt 255 ] && return 1; done
    return 0
}

validate_port() {
    [[ "$1" =~ ^[0-9]+$ ]] && [ "$1" -ge 1 ] && [ "$1" -le 65535 ]
}

clean_name() {
    local n
    n=$(echo "$1" | tr -cd '[:alnum:]-_')
    echo "${n:-tunnel}"
}

gen_key() {
    command -v openssl &>/dev/null \
        && openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c 32 \
        || tr -dc 'a-zA-Z0-9' </dev/urandom | head -c 32
}

check_port_in_use() {
    local port="$1"
    if ss -tuln 2>/dev/null | grep -q ":${port} "; then
        p_warn "Port ${port} is already in use!"
        local pid
        pid=$(lsof -t -i:"$port" 2>/dev/null | head -1)
        if [ -n "$pid" ]; then
            local pname
            pname=$(ps -p "$pid" -o comm= 2>/dev/null || echo "unknown")
            p_info "Used by: ${pname} (PID: ${pid})"
            read -r -p "  Kill this process? (y/N): " kc
            if [[ "$kc" =~ ^[Yy]$ ]]; then
                kill -9 "$pid" 2>/dev/null || true
                sleep 1
                p_ok "Process killed"
            else
                return 1
            fi
        fi
    fi
    return 0
}

save_iptables() {
    command -v netfilter-persistent &>/dev/null \
        && netfilter-persistent save >/dev/null 2>&1 && return
    mkdir -p /etc/iptables
    iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
}

get_all_services() {
    systemctl list-unit-files --type=service --no-legend --no-pager 2>/dev/null \
        | awk '/^avash-/{print $1}'
}

# =============================================================================
# PAQET CORE INSTALLER
# =============================================================================

_extract_paqet() {
    local tarfile="$1"
    mkdir -p /opt/paqet
    rm -rf /opt/paqet/*
    tar -xzf "$tarfile" -C /opt/paqet 2>/dev/null
    rm -f "$tarfile"

    local bin
    bin=$(find /opt/paqet -type f \( -name "paqet*" -o -name "*paqet*" \) \
        ! -name "*.tar*" ! -name "*.gz" 2>/dev/null | head -1)
    [ -z "$bin" ] && bin=$(find /opt/paqet -type f -executable 2>/dev/null | head -1)

    if [ -n "$bin" ] && [ -f "$bin" ]; then
        cp "$bin" "$BIN_DIR/paqet"
        chmod +x "$BIN_DIR/paqet"
        p_ok "Paqet installed → ${BIN_DIR}/paqet"
        local ver
        ver=$("$BIN_DIR/paqet" version 2>/dev/null | head -1 || echo "unknown")
        p_info "Version: ${ver}"
        return 0
    fi
    p_err "Binary not found inside the archive."
    ls -la /opt/paqet/ 2>/dev/null
    return 1
}

paqet_auto_install() {
    local arch
    arch=$(detect_arch) || return 1
    local url
    [ "$arch" = "arm64" ] && url="$PAQET_ARM64" || url="$PAQET_AMD64"

    p_step "Auto-installing Paqet AVASH build (${PAQET_VER})..."
    if curl -fsSL --progress-bar "$url" -o /tmp/paqet_dl.tar.gz 2>/dev/null; then
        _extract_paqet /tmp/paqet_dl.tar.gz && return 0
    fi
    p_warn "AVASH build failed. Trying upstream GitHub..."
    local latest fname fallback
    latest=$(curl -s "https://api.github.com/repos/${PAQET_REPO}/releases/latest" \
        2>/dev/null | grep '"tag_name"' | cut -d'"' -f4)
    latest="${latest:-v1.0.0-alpha.16}"
    fname="paqet-linux-${arch}-${latest}.tar.gz"
    fallback="https://github.com/${PAQET_REPO}/releases/download/${latest}/${fname}"
    curl -fsSL --progress-bar "$fallback" -o /tmp/paqet_dl.tar.gz 2>/dev/null
    _extract_paqet /tmp/paqet_dl.tar.gz
}

install_paqet_menu() {
    while true; do
        show_banner
        box "Install / Update Paqet Core"

        local arch cur_ver ins_label
        arch=$(detect_arch 2>/dev/null || echo "unknown")

        if [ -f "$BIN_DIR/paqet" ]; then
            cur_ver=$("$BIN_DIR/paqet" version 2>/dev/null | head -1 || echo "unknown")
            ins_label="${GREEN}Installed — ${cur_ver}${NC}"
        else
            ins_label="${YELLOW}Not installed${NC}"
        fi

        echo -e "  Current Status  : $(echo -e "$ins_label")"
        echo -e "  System Arch     : ${CYAN}${arch}${NC}"
        echo -e "  AVASH Version   : ${CYAN}${PAQET_VER}${NC}"
        echo ""
        line
        echo -e "  ${BOLD}${GREEN}AVASH Optimized Build  (Recommended)${NC}"
        line
        echo -e "  ${WHITE}[1]${NC}  Install AMD64   ${DIM}— x86_64, most VPS servers${NC}"
        echo -e "       ${DIM}${PAQET_AMD64}${NC}"
        echo ""
        echo -e "  ${WHITE}[2]${NC}  Install ARM64   ${DIM}— Oracle Free Tier, ARM servers${NC}"
        echo -e "       ${DIM}${PAQET_ARM64}${NC}"
        echo ""
        echo -e "  ${WHITE}[3]${NC}  Auto-detect & Install  ${DIM}— detects your arch automatically${NC}"
        echo ""
        line
        echo -e "  ${BOLD}${CYAN}Other Options${NC}"
        line
        echo -e "  ${WHITE}[4]${NC}  Download from upstream GitHub  ${DIM}(${PAQET_REPO})${NC}"
        echo -e "  ${WHITE}[5]${NC}  Install from local file        ${DIM}(tar.gz in /root/)${NC}"
        echo -e "  ${WHITE}[6]${NC}  Install from custom URL"
        echo -e "  ${WHITE}[7]${NC}  Remove Paqet"
        echo ""
        echo -e "  ${WHITE}[0]${NC}  Back to Main Menu"
        echo ""
        read -r -p "  Choose [0-7]: " ch

        case "$ch" in
            1)
                echo ""
                p_step "Downloading AMD64 AVASH build..."
                if curl -fsSL --progress-bar "$PAQET_AMD64" -o /tmp/paqet_dl.tar.gz; then
                    _extract_paqet /tmp/paqet_dl.tar.gz \
                        && p_ok "Installation successful!" \
                        || p_err "Installation failed."
                else
                    p_err "Download failed. Check server internet connection."
                fi
                pause
                ;;
            2)
                echo ""
                p_step "Downloading ARM64 AVASH build..."
                if curl -fsSL --progress-bar "$PAQET_ARM64" -o /tmp/paqet_dl.tar.gz; then
                    _extract_paqet /tmp/paqet_dl.tar.gz \
                        && p_ok "Installation successful!" \
                        || p_err "Installation failed."
                else
                    p_err "Download failed. Check server internet connection."
                fi
                pause
                ;;
            3)
                echo ""
                p_step "Detected architecture: ${arch}"
                local auto_url
                if [ "$arch" = "arm64" ]; then
                    auto_url="$PAQET_ARM64"
                    p_info "Selecting ARM64 build..."
                else
                    auto_url="$PAQET_AMD64"
                    p_info "Selecting AMD64 build..."
                fi
                if curl -fsSL --progress-bar "$auto_url" -o /tmp/paqet_dl.tar.gz; then
                    _extract_paqet /tmp/paqet_dl.tar.gz \
                        && p_ok "Auto-install successful!" \
                        || p_err "Installation failed."
                else
                    p_err "Download failed."
                fi
                pause
                ;;
            4)
                echo ""
                p_step "Fetching latest version from GitHub..."
                local latest fname url
                latest=$(curl -s \
                    "https://api.github.com/repos/${PAQET_REPO}/releases/latest" \
                    2>/dev/null | grep '"tag_name"' | cut -d'"' -f4)
                latest="${latest:-v1.0.0-alpha.16}"
                fname="paqet-linux-${arch}-${latest}.tar.gz"
                url="https://github.com/${PAQET_REPO}/releases/download/${latest}/${fname}"
                p_info "Version : ${latest}"
                p_info "URL     : ${url}"
                if curl -fsSL --progress-bar "$url" -o /tmp/paqet_dl.tar.gz; then
                    _extract_paqet /tmp/paqet_dl.tar.gz \
                        && p_ok "Installation successful!" \
                        || p_err "Installation failed."
                else
                    p_err "Download failed. Version ${latest} may not exist for ${arch}."
                fi
                pause
                ;;
            5)
                echo ""
                p_info "Scanning /root/ for .tar.gz files..."
                local files=()
                mapfile -t files < <(find /root/ -maxdepth 2 -name "*.tar.gz" 2>/dev/null | sort)
                if [ ${#files[@]} -eq 0 ]; then
                    p_warn "No .tar.gz files found in /root/"
                    pause
                    continue
                fi
                local idx=1
                for f in "${files[@]}"; do
                    local sz
                    sz=$(du -h "$f" 2>/dev/null | cut -f1)
                    echo -e "  ${WHITE}[${idx}]${NC} $(basename "$f")  ${DIM}(${sz})${NC}"
                    ((idx++))
                done
                echo ""
                read -r -p "  Select file number: " fnum
                if [[ "$fnum" =~ ^[0-9]+$ ]] \
                    && [ "$fnum" -ge 1 ] && [ "$fnum" -le "${#files[@]}" ]; then
                    cp "${files[$((fnum-1))]}" /tmp/paqet_dl.tar.gz
                    _extract_paqet /tmp/paqet_dl.tar.gz \
                        && p_ok "Installation successful!" \
                        || p_err "Installation failed."
                else
                    p_err "Invalid selection."
                fi
                pause
                ;;
            6)
                echo ""
                read -r -p "  Enter URL: " custom_url
                [ -z "$custom_url" ] && { p_err "URL cannot be empty."; pause; continue; }
                p_step "Downloading from ${custom_url}..."
                if curl -fsSL --progress-bar "$custom_url" -o /tmp/paqet_dl.tar.gz; then
                    _extract_paqet /tmp/paqet_dl.tar.gz \
                        && p_ok "Installation successful!" \
                        || p_err "Installation failed."
                else
                    p_err "Download failed."
                fi
                pause
                ;;
            7)
                echo ""
                read -r -p "  Remove Paqet binary? (y/N): " confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    rm -f "$BIN_DIR/paqet"
                    rm -rf /opt/paqet
                    p_ok "Paqet removed."
                fi
                pause
                ;;
            0) return ;;
            *) p_err "Invalid choice."; sleep 1 ;;
        esac
    done
}

# =============================================================================
# KCP HELPERS
# =============================================================================

# Global output vars (avoid subshell capture problems with read)
KCP_MODE_RESULT=""
KCP_EXTRA_PARAMS=""
KCP_ENC_RESULT=""

_select_kcp_mode() {
    # Sets KCP_MODE_RESULT
    echo ""
    echo -e "  ${CYAN}KCP Mode:${NC}"
    for k in 0 1 2 3 4; do
        IFS=':' read -r mname mdesc <<< "${KCP_MODES[$k]}"
        echo -e "  ${WHITE}[${k}]${NC} ${mname}  ${DIM}— ${mdesc}${NC}"
    done
    echo ""
    read -r -p "  Choose mode [0-4] (default 1): " mc
    mc="${mc:-1}"
    case "$mc" in
        0) KCP_MODE_RESULT="normal"  ;;
        1) KCP_MODE_RESULT="fast"    ;;
        2) KCP_MODE_RESULT="fast2"   ;;
        3) KCP_MODE_RESULT="fast3"   ;;
        4) KCP_MODE_RESULT="manual"  ;;
        *) KCP_MODE_RESULT="fast"    ;;
    esac
}

_manual_kcp_params() {
    # Sets KCP_EXTRA_PARAMS
    echo -e "  ${CYAN}Manual KCP Parameters:${NC}"
    local nd iv rs nc rw sw
    read -r -p "  nodelay      [0-2]  (default 1) : " nd; nd="${nd:-1}"
    read -r -p "  interval     [ms]   (default 20): " iv; iv="${iv:-20}"
    read -r -p "  resend       [0-N]  (default 1) : " rs; rs="${rs:-1}"
    read -r -p "  nocongestion [0/1]  (default 1) : " nc; nc="${nc:-1}"
    read -r -p "  rcvwnd               (default 2048): " rw; rw="${rw:-2048}"
    read -r -p "  sndwnd               (default 2048): " sw; sw="${sw:-2048}"
    KCP_EXTRA_PARAMS="$(printf "nodelay: %s\ninterval: %s\nresend: %s\nnocongestion: %s\nrcvwnd: %s\nsndwnd: %s" \
        "$nd" "$iv" "$rs" "$nc" "$rw" "$sw")"
}

_select_encryption() {
    # Sets KCP_ENC_RESULT
    echo ""
    echo -e "  ${CYAN}Encryption:${NC}"
    for k in 1 2 3 4 5; do
        IFS=':' read -r ename edesc <<< "${ENCRYPTIONS[$k]}"
        echo -e "  ${WHITE}[${k}]${NC} ${ename}  ${DIM}— ${edesc}${NC}"
    done
    echo ""
    read -r -p "  Choose [1-5] (default 1): " ec
    ec="${ec:-1}"
    local enc
    IFS=':' read -r enc _ <<< "${ENCRYPTIONS[$ec]}"
    KCP_ENC_RESULT="${enc:-aes-128-gcm}"
}

_setup_kcp_iptables() {
    local port="$1"
    p_step "Configuring iptables for KCP port ${port}..."
    iptables -t raw -D PREROUTING -p tcp --dport "$port" -j NOTRACK 2>/dev/null || true
    iptables -t raw -D OUTPUT     -p tcp --sport "$port" -j NOTRACK 2>/dev/null || true
    iptables -t raw -A PREROUTING -p tcp --dport "$port" -j NOTRACK
    iptables -t raw -A OUTPUT     -p tcp --sport "$port" -j NOTRACK
    iptables -t mangle -D OUTPUT  -p tcp --sport "$port" --tcp-flags RST RST -j DROP 2>/dev/null || true
    iptables -t mangle -A OUTPUT  -p tcp --sport "$port" --tcp-flags RST RST -j DROP
    save_iptables
}

_add_cron_restart() {
    local svc="$1" interval="${2:-$DEFAULT_AUTO_RESTART}"
    local cron_expr="${CRON_INTERVALS[$interval]}"
    [ -z "$cron_expr" ] && return
    local cmd="systemctl restart ${svc}"
    (crontab -l 2>/dev/null | grep -v "$cmd"; echo "$cron_expr $cmd") | crontab -
}

_make_systemd_service() {
    local name="$1" exec_cmd="$2" desc="$3"
    cat > "$SERVICE_DIR/${name}.service" << EOF
[Unit]
Description=${desc}
After=network.target
StartLimitIntervalSec=0

[Service]
Type=simple
ExecStart=${exec_cmd}
Restart=always
RestartSec=5
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
}

# =============================================================================
# KCP TUNNEL
# =============================================================================

configure_kcp_server() {
    show_banner
    box "KCP Server — Configure  (Abroad / Kharej)"

    get_network_info
    local pub_ip
    pub_ip=$(get_public_ip)

    echo -e "  ${CYAN}Interface ${NC}: ${WHITE}${NETWORK_INTERFACE}${NC}"
    echo -e "  ${CYAN}Local IP  ${NC}: ${WHITE}${LOCAL_IP}${NC}"
    echo -e "  ${CYAN}Public IP ${NC}: ${GREEN}${pub_ip}${NC}"
    echo -e "  ${CYAN}Gateway   ${NC}: ${WHITE}${GATEWAY_MAC:-N/A}${NC}"
    echo ""

    # [1] Name
    read -r -p "$(echo -e "  ${YELLOW}[1] Service name (e.g. kcp-server): ${NC}")" cfg
    cfg=$(clean_name "${cfg:-kcp-server}")
    if [ -f "$CONFIG_DIR/kcp/${cfg}.yaml" ]; then
        p_warn "Config '${cfg}' already exists!"
        read -r -p "  Overwrite? (y/N): " ow
        [[ ! "$ow" =~ ^[Yy]$ ]] && return
    fi

    # [2] Port
    read -r -p "$(echo -e "  ${YELLOW}[2] Listen port (default: ${DEFAULT_PORT}): ${NC}")" port
    port="${port:-$DEFAULT_PORT}"
    validate_port "$port" || { p_err "Invalid port number."; pause; return; }
    check_port_in_use "$port" || { pause; return; }

    # [3] Secret Key
    local skey
    skey=$(gen_key)
    echo ""
    echo -e "  ${YELLOW}[3] Secret key (auto-generated):${NC}"
    echo -e "      ${GREEN}${BOLD}${skey}${NC}"
    read -r -p "  Use this key? (Y/n): " uk
    if [[ "$uk" =~ ^[Nn]$ ]]; then
        read -r -p "  Enter custom key (min 8 chars): " skey
        [ "${#skey}" -lt 8 ] && { p_err "Key too short (minimum 8 characters)."; pause; return; }
    fi

    # [4] KCP Mode
    _select_kcp_mode
    local mode="$KCP_MODE_RESULT"
    KCP_EXTRA_PARAMS=""
    [ "$mode" = "manual" ] && _manual_kcp_params

    # [5] Connections
    read -r -p "$(echo -e "  ${YELLOW}[5] Connections [1-32] (default: ${DEFAULT_CONNECTIONS}): ${NC}")" conn
    conn="${conn:-$DEFAULT_CONNECTIONS}"
    [[ ! "$conn" =~ ^[0-9]+$ ]] || [ "$conn" -lt 1 ] || [ "$conn" -gt 32 ] \
        && conn="$DEFAULT_CONNECTIONS"

    # [6] MTU
    read -r -p "$(echo -e "  ${YELLOW}[6] MTU [100-9000] (default: ${DEFAULT_MTU}): ${NC}")" mtu
    mtu="${mtu:-$DEFAULT_MTU}"
    [[ ! "$mtu" =~ ^[0-9]+$ ]] || [ "$mtu" -lt 100 ] || [ "$mtu" -gt 9000 ] \
        && mtu="$DEFAULT_MTU"

    # [7] Encryption
    _select_encryption
    local enc="$KCP_ENC_RESULT"

    # Install Paqet if missing
    if [ ! -f "$BIN_DIR/paqet" ]; then
        p_warn "Paqet not found — installing automatically..."
        paqet_auto_install || { p_err "Cannot install Paqet. Aborting."; pause; return; }
    fi

    _setup_kcp_iptables "$port"

    mkdir -p "$CONFIG_DIR/kcp"
    {
        echo "# AVASH KCP Server — ${cfg}"
        echo "# Created: $(date)"
        echo "role: \"server\""
        echo "log:"
        echo "  level: \"info\""
        echo "listen:"
        echo "  addr: \":${port}\""
        echo "network:"
        echo "  interface: \"${NETWORK_INTERFACE}\""
        echo "  ipv4:"
        echo "    addr: \"${LOCAL_IP}:${port}\""
        [ -n "$GATEWAY_MAC" ] && echo "    router_mac: \"${GATEWAY_MAC}\""
        echo "  tcp:"
        echo "    local_flag: [\"PA\"]"
        echo "transport:"
        echo "  protocol: \"kcp\""
        echo "  conn: ${conn}"
        echo "  kcp:"
        echo "    key: \"${skey}\""
        echo "    mode: \"${mode}\""
        echo "    block: \"${enc}\""
        echo "    mtu: ${mtu}"
        if [ "$mode" = "manual" ] && [ -n "$KCP_EXTRA_PARAMS" ]; then
            while IFS= read -r line; do
                [ -n "$line" ] && echo "    ${line}"
            done <<< "$KCP_EXTRA_PARAMS"
        fi
    } > "$CONFIG_DIR/kcp/${cfg}.yaml"

    local svc="avash-kcp-${cfg}"
    _make_systemd_service "$svc" \
        "${BIN_DIR}/paqet run -c ${CONFIG_DIR}/kcp/${cfg}.yaml" \
        "AVASH KCP Server — ${cfg}"

    systemctl enable "$svc" --now >/dev/null 2>&1
    sleep 2

    echo ""
    if systemctl is-active --quiet "$svc"; then
        _add_cron_restart "$svc"
        echo -e "${GREEN}  ╔══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}  ║  ✅  KCP Server is running!                                  ║${NC}"
        echo -e "${GREEN}  ╚══════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        printf "  ${CYAN}%-16s${NC}: ${WHITE}%s${NC}\n" "Public IP"    "$pub_ip"
        printf "  ${CYAN}%-16s${NC}: ${WHITE}%s${NC}\n" "Listen Port"  "$port"
        printf "  ${CYAN}%-16s${NC}: ${WHITE}%s${NC}\n" "KCP Mode"     "$mode"
        printf "  ${CYAN}%-16s${NC}: ${WHITE}%s${NC}\n" "Encryption"   "$enc"
        printf "  ${CYAN}%-16s${NC}: ${WHITE}%s${NC}\n" "Connections"  "$conn"
        printf "  ${CYAN}%-16s${NC}: ${WHITE}%s${NC}\n" "MTU"          "$mtu"
        printf "  ${CYAN}%-16s${NC}: ${WHITE}%s${NC}\n" "Auto-Restart" "Every ${DEFAULT_AUTO_RESTART}"
        echo ""
        echo -e "  ${YELLOW}Secret key — save this for your client:${NC}"
        echo -e "  ${GREEN}${BOLD}${skey}${NC}"
    else
        p_err "Service failed to start!"
        journalctl -u "$svc" -n 20 --no-pager
    fi
    pause
}

configure_kcp_client() {
    show_banner
    box "KCP Client — Configure  (Iran / Domestic)"

    get_network_info

    # [1] Name
    read -r -p "$(echo -e "  ${YELLOW}[1] Service name (e.g. kcp-client): ${NC}")" cfg
    cfg=$(clean_name "${cfg:-kcp-client}")

    # [2] Server IP
    read -r -p "$(echo -e "  ${YELLOW}[2] Server IP (Kharej / Abroad): ${NC}")" srv_ip
    [ -z "$srv_ip" ] && { p_err "Server IP is required."; pause; return; }
    validate_ip "$srv_ip" || { p_err "Invalid IP address."; pause; return; }

    # [3] Server Port
    read -r -p "$(echo -e "  ${YELLOW}[3] Server port (default: ${DEFAULT_PORT}): ${NC}")" srv_port
    srv_port="${srv_port:-$DEFAULT_PORT}"
    validate_port "$srv_port" || { p_err "Invalid port number."; pause; return; }

    # [4] Secret Key
    read -r -p "$(echo -e "  ${YELLOW}[4] Secret key (from server): ${NC}")" skey
    [ -z "$skey" ] && { p_err "Secret key is required."; pause; return; }

    # [5] KCP Mode
    _select_kcp_mode
    local mode="$KCP_MODE_RESULT"
    KCP_EXTRA_PARAMS=""
    [ "$mode" = "manual" ] && _manual_kcp_params

    # [6] Connections
    read -r -p "$(echo -e "  ${YELLOW}[6] Connections [1-32] (default: ${DEFAULT_CONNECTIONS}): ${NC}")" conn
    conn="${conn:-$DEFAULT_CONNECTIONS}"
    [[ ! "$conn" =~ ^[0-9]+$ ]] && conn="$DEFAULT_CONNECTIONS"

    # [7] MTU
    read -r -p "$(echo -e "  ${YELLOW}[7] MTU (default: ${DEFAULT_MTU}): ${NC}")" mtu
    mtu="${mtu:-$DEFAULT_MTU}"

    # [8] Encryption
    _select_encryption
    local enc="$KCP_ENC_RESULT"

    # [9] Traffic Mode
    echo ""
    echo -e "  ${CYAN}Traffic Mode:${NC}"
    echo -e "  ${WHITE}[1]${NC} Port Forwarding  ${DIM}— forward ports through the tunnel${NC}"
    echo -e "  ${WHITE}[2]${NC} SOCKS5 Proxy     ${DIM}— local SOCKS5 proxy on this server${NC}"
    echo ""
    read -r -p "  Choose [1-2] (default 1): " tmode
    tmode="${tmode:-1}"

    local fwd_type=""
    local fwd_ports=""
    local socks_port=""

    if [ "$tmode" = "2" ]; then
        read -r -p "  SOCKS5 listen port (default 1080): " socks_port
        socks_port="${socks_port:-1080}"
        fwd_type="socks5"
    else
        read -r -p "  Ports to forward (e.g. 443,80,8443): " fwd_ports
        fwd_ports="${fwd_ports:-443}"
        fwd_type="forward"
    fi

    # Install Paqet if missing
    if [ ! -f "$BIN_DIR/paqet" ]; then
        p_warn "Paqet not found — installing automatically..."
        paqet_auto_install || { p_err "Cannot install Paqet. Aborting."; pause; return; }
    fi

    mkdir -p "$CONFIG_DIR/kcp"
    {
        echo "# AVASH KCP Client — ${cfg}"
        echo "# Created: $(date)"
        echo "role: \"client\""
        echo "log:"
        echo "  level: \"info\""

        if [ "$fwd_type" = "socks5" ]; then
            echo "socks5:"
            echo "  - listen: \"0.0.0.0:${socks_port}\""
            echo "    username: \"\""
            echo "    password: \"\""
        else
            echo "forward:"
            IFS=',' read -ra plist <<< "$fwd_ports"
            for p in "${plist[@]}"; do
                p=$(echo "$p" | tr -d '[:space:]')
                if validate_port "$p"; then
                    echo "  - listen: \"0.0.0.0:${p}\""
                    echo "    target: \"127.0.0.1:${p}\""
                    echo "    protocol: \"tcp\""
                fi
            done
        fi

        echo "network:"
        echo "  interface: \"${NETWORK_INTERFACE}\""
        echo "  ipv4:"
        echo "    addr: \"${LOCAL_IP}:0\""
        [ -n "$GATEWAY_MAC" ] && echo "    router_mac: \"${GATEWAY_MAC}\""
        echo "  tcp:"
        echo "    local_flag: [\"PA\"]"
        echo "server:"
        echo "  addr: \"${srv_ip}:${srv_port}\""
        echo "transport:"
        echo "  protocol: \"kcp\""
        echo "  conn: ${conn}"
        echo "  kcp:"
        echo "    mode: \"${mode}\""
        echo "    key: \"${skey}\""
        echo "    block: \"${enc}\""
        echo "    mtu: ${mtu}"
        if [ "$mode" = "manual" ] && [ -n "$KCP_EXTRA_PARAMS" ]; then
            while IFS= read -r line; do
                [ -n "$line" ] && echo "    ${line}"
            done <<< "$KCP_EXTRA_PARAMS"
        fi
    } > "$CONFIG_DIR/kcp/${cfg}.yaml"

    local svc="avash-kcp-${cfg}"
    _make_systemd_service "$svc" \
        "${BIN_DIR}/paqet run -c ${CONFIG_DIR}/kcp/${cfg}.yaml" \
        "AVASH KCP Client — ${cfg}"

    systemctl enable "$svc" --now >/dev/null 2>&1
    sleep 2

    echo ""
    if systemctl is-active --quiet "$svc"; then
        _add_cron_restart "$svc"
        p_ok "KCP Client is running!"
        echo ""
        printf "  ${CYAN}%-14s${NC}: ${WHITE}%s${NC}\n" "Server"      "${srv_ip}:${srv_port}"
        printf "  ${CYAN}%-14s${NC}: ${WHITE}%s${NC}\n" "KCP Mode"    "$mode"
        printf "  ${CYAN}%-14s${NC}: ${WHITE}%s${NC}\n" "Encryption"  "$enc"
        if [ "$fwd_type" = "socks5" ]; then
            printf "  ${CYAN}%-14s${NC}: ${WHITE}%s${NC}\n" "SOCKS5 Port" "$socks_port"
        else
            printf "  ${CYAN}%-14s${NC}: ${WHITE}%s${NC}\n" "Forwarded"   "$fwd_ports"
        fi
    else
        p_err "Service failed to start!"
        journalctl -u "$svc" -n 20 --no-pager
    fi
    pause
}

# =============================================================================
# WIREGUARD
# =============================================================================

_wg_install() {
    local os
    os=$(detect_os)
    p_step "Installing WireGuard..."
    case $os in
        ubuntu|debian)
            apt-get update -qq >/dev/null 2>&1
            apt-get install -y wireguard wireguard-tools >/dev/null 2>&1 ;;
        centos|rhel|rocky|almalinux)
            yum install -y epel-release >/dev/null 2>&1
            yum install -y wireguard-tools kmod-wireguard >/dev/null 2>&1 ;;
        fedora) dnf install -y wireguard-tools >/dev/null 2>&1 ;;
        *) p_err "Please install WireGuard manually."; return 1 ;;
    esac
    command -v wg &>/dev/null \
        && p_ok "WireGuard installed." \
        || { p_err "WireGuard installation failed."; return 1; }
}

_wg_service() {
    local iface="$1"
    cat > "$SERVICE_DIR/avash-wg-${iface}.service" << EOF
[Unit]
Description=AVASH WireGuard — ${iface}
After=network.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/wg-quick up ${CONFIG_DIR}/wg/${iface}.conf
ExecStop=/usr/bin/wg-quick down ${CONFIG_DIR}/wg/${iface}.conf

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
}

configure_wireguard_server() {
    show_banner
    box "WireGuard Server — Configure"

    command -v wg &>/dev/null || { _wg_install || { pause; return; }; }

    get_network_info
    local pub_ip
    pub_ip=$(get_public_ip)

    read -r -p "$(echo -e "  ${YELLOW}[1] Interface name (e.g. wg0): ${NC}")" iface
    iface="${iface:-wg0}"
    iface=$(echo "$iface" | tr -cd 'a-zA-Z0-9_-')

    read -r -p "$(echo -e "  ${YELLOW}[2] Listen port (default: ${DEFAULT_WG_PORT}): ${NC}")" wg_port
    wg_port="${wg_port:-$DEFAULT_WG_PORT}"
    validate_port "$wg_port" || { p_err "Invalid port."; pause; return; }

    read -r -p "$(echo -e "  ${YELLOW}[3] Server tunnel IP (e.g. 10.0.0.1): ${NC}")" tun_ip
    tun_ip="${tun_ip:-10.0.0.1}"

    read -r -p "$(echo -e "  ${YELLOW}[4] Subnet prefix length (default: 24): ${NC}")" cidr
    cidr="${cidr:-24}"

    read -r -p "$(echo -e "  ${YELLOW}[5] MTU (default: 1420): ${NC}")" wg_mtu
    wg_mtu="${wg_mtu:-1420}"

    p_step "Generating WireGuard key pair..."
    local priv pub
    priv=$(wg genkey)
    pub=$(echo "$priv" | wg pubkey)

    echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
    sysctl -p >/dev/null 2>&1

    mkdir -p "$CONFIG_DIR/wg"
    chmod 700 "$CONFIG_DIR/wg"

    cat > "$CONFIG_DIR/wg/${iface}.conf" << EOF
# AVASH WireGuard Server — ${iface}
# Created: $(date)
# Public Key: ${pub}

[Interface]
PrivateKey = ${priv}
Address = ${tun_ip}/${cidr}
ListenPort = ${wg_port}
MTU = ${wg_mtu}
PostUp   = iptables -A FORWARD -i %i -j ACCEPT; iptables -t nat -A POSTROUTING -o ${NETWORK_INTERFACE} -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -t nat -D POSTROUTING -o ${NETWORK_INTERFACE} -j MASQUERADE

# Add clients below:
# [Peer]
# PublicKey = <client_public_key>
# AllowedIPs = 10.0.0.2/32
EOF
    chmod 600 "$CONFIG_DIR/wg/${iface}.conf"

    _wg_service "$iface"
    local svc="avash-wg-${iface}"
    systemctl enable "$svc" --now >/dev/null 2>&1
    sleep 2

    echo ""
    if systemctl is-active --quiet "$svc"; then
        _add_cron_restart "$svc"
        p_ok "WireGuard Server is running!"
        echo ""
        printf "  ${CYAN}%-14s${NC}: ${WHITE}%s${NC}\n" "Public IP"  "$pub_ip"
        printf "  ${CYAN}%-14s${NC}: ${WHITE}%s${NC}\n" "Port"       "$wg_port"
        printf "  ${CYAN}%-14s${NC}: ${WHITE}%s${NC}\n" "Tunnel IP"  "${tun_ip}/${cidr}"
        printf "  ${CYAN}%-14s${NC}: ${WHITE}%s${NC}\n" "Interface"  "$iface"
        echo ""
        echo -e "  ${YELLOW}Server Public Key — share this with clients:${NC}"
        echo -e "  ${GREEN}${BOLD}${pub}${NC}"
        echo ""
        echo -e "  ${DIM}Config file: ${CONFIG_DIR}/wg/${iface}.conf${NC}"
    else
        p_err "WireGuard failed to start!"
        journalctl -u "$svc" -n 20 --no-pager
    fi
    pause
}

configure_wireguard_client() {
    show_banner
    box "WireGuard Client — Configure"

    command -v wg &>/dev/null || { _wg_install || { pause; return; }; }

    get_network_info

    read -r -p "$(echo -e "  ${YELLOW}[1] Interface name (e.g. wg0): ${NC}")" iface
    iface="${iface:-wg0}"

    read -r -p "$(echo -e "  ${YELLOW}[2] Client tunnel IP (e.g. 10.0.0.2): ${NC}")" cli_ip
    cli_ip="${cli_ip:-10.0.0.2}"

    read -r -p "$(echo -e "  ${YELLOW}[3] Server public IP: ${NC}")" srv_ip
    [ -z "$srv_ip" ] && { p_err "Server IP is required."; pause; return; }

    read -r -p "$(echo -e "  ${YELLOW}[4] Server port (default: ${DEFAULT_WG_PORT}): ${NC}")" srv_port
    srv_port="${srv_port:-$DEFAULT_WG_PORT}"

    read -r -p "$(echo -e "  ${YELLOW}[5] Server public key: ${NC}")" srv_pub
    [ -z "$srv_pub" ] && { p_err "Server public key is required."; pause; return; }

    read -r -p "$(echo -e "  ${YELLOW}[6] Allowed IPs (default: 0.0.0.0/0): ${NC}")" allowed
    allowed="${allowed:-0.0.0.0/0}"

    read -r -p "$(echo -e "  ${YELLOW}[7] DNS server (default: 1.1.1.1): ${NC}")" dns
    dns="${dns:-1.1.1.1}"

    read -r -p "$(echo -e "  ${YELLOW}[8] MTU (default: 1420): ${NC}")" wg_mtu
    wg_mtu="${wg_mtu:-1420}"

    p_step "Generating client key pair..."
    local priv pub
    priv=$(wg genkey)
    pub=$(echo "$priv" | wg pubkey)

    mkdir -p "$CONFIG_DIR/wg"
    chmod 700 "$CONFIG_DIR/wg"

    cat > "$CONFIG_DIR/wg/${iface}.conf" << EOF
# AVASH WireGuard Client — ${iface}
# Created: $(date)

[Interface]
PrivateKey = ${priv}
Address = ${cli_ip}/32
DNS = ${dns}
MTU = ${wg_mtu}

[Peer]
PublicKey = ${srv_pub}
Endpoint = ${srv_ip}:${srv_port}
AllowedIPs = ${allowed}
PersistentKeepalive = 25
EOF
    chmod 600 "$CONFIG_DIR/wg/${iface}.conf"

    _wg_service "$iface"
    local svc="avash-wg-${iface}"
    systemctl enable "$svc" --now >/dev/null 2>&1
    sleep 2

    echo ""
    if systemctl is-active --quiet "$svc"; then
        _add_cron_restart "$svc"
        p_ok "WireGuard Client is running!"
        echo ""
        printf "  ${CYAN}%-14s${NC}: ${WHITE}%s${NC}\n" "Client IP"  "$cli_ip"
        printf "  ${CYAN}%-14s${NC}: ${WHITE}%s${NC}\n" "Server"     "${srv_ip}:${srv_port}"
        printf "  ${CYAN}%-14s${NC}: ${WHITE}%s${NC}\n" "AllowedIPs" "$allowed"
        echo ""
        echo -e "  ${YELLOW}Client Public Key — add this to server config:${NC}"
        echo -e "  ${GREEN}${BOLD}${pub}${NC}"
    else
        p_err "WireGuard client failed to start!"
        journalctl -u "$svc" -n 20 --no-pager
    fi
    pause
}

# =============================================================================
# GRE TUNNEL
# =============================================================================

configure_gre() {
    show_banner
    box "GRE Tunnel — Configure"

    echo -e "  ${DIM}GRE encapsulates IP packets. Fast but unencrypted.${NC}"
    echo -e "  ${DIM}Must be configured on BOTH servers with swapped IPs.${NC}"
    echo ""

    get_network_info

    read -r -p "$(echo -e "  ${YELLOW}[1] Tunnel name (e.g. gre-iran): ${NC}")" tname
    tname=$(clean_name "${tname:-gre0}")

    read -r -p "$(echo -e "  ${YELLOW}[2] Local WAN IP (this server): ${NC}")" lip
    lip="${lip:-$LOCAL_IP}"

    read -r -p "$(echo -e "  ${YELLOW}[3] Remote WAN IP (other server): ${NC}")" rip
    [ -z "$rip" ] && { p_err "Remote IP is required."; pause; return; }
    validate_ip "$rip" || { p_err "Invalid IP address."; pause; return; }

    read -r -p "$(echo -e "  ${YELLOW}[4] Tunnel local IP  (e.g. 172.16.0.1): ${NC}")" tun_l
    tun_l="${tun_l:-172.16.0.1}"

    read -r -p "$(echo -e "  ${YELLOW}[5] Tunnel remote IP (e.g. 172.16.0.2): ${NC}")" tun_r
    tun_r="${tun_r:-172.16.0.2}"

    read -r -p "$(echo -e "  ${YELLOW}[6] TTL (default: 255): ${NC}")" ttl
    ttl="${ttl:-255}"

    p_step "Loading ip_gre module..."
    modprobe ip_gre 2>/dev/null || true

    p_step "Creating GRE tunnel: ${tname}..."
    ip tunnel del "$tname" 2>/dev/null || true
    ip tunnel add "$tname" mode gre local "$lip" remote "$rip" ttl "$ttl"
    ip link set "$tname" up
    ip addr add "${tun_l}/30" dev "$tname" 2>/dev/null || true
    ip link set "$tname" mtu 1476

    mkdir -p "$CONFIG_DIR/gre"
    printf 'TUNNEL_NAME="%s"\nLOCAL_IP="%s"\nREMOTE_IP="%s"\nTUN_LOCAL="%s"\nTUN_REMOTE="%s"\nTTL="%s"\n' \
        "$tname" "$lip" "$rip" "$tun_l" "$tun_r" "$ttl" \
        > "$CONFIG_DIR/gre/${tname}.conf"

    cat > "$SERVICE_DIR/avash-gre-${tname}.service" << EOF
[Unit]
Description=AVASH GRE Tunnel — ${tname}
After=network.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/bash -c 'modprobe ip_gre; ip tunnel add ${tname} mode gre local ${lip} remote ${rip} ttl ${ttl}; ip link set ${tname} up; ip addr add ${tun_l}/30 dev ${tname}; ip link set ${tname} mtu 1476'
ExecStop=/bin/bash -c 'ip tunnel del ${tname}'

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable "avash-gre-${tname}" >/dev/null 2>&1

    echo ""
    if ip link show "$tname" 2>/dev/null | grep -q "UP"; then
        p_ok "GRE Tunnel is active!"
        echo ""
        printf "  ${CYAN}%-14s${NC}: ${WHITE}%s${NC}\n" "Interface"   "$tname"
        printf "  ${CYAN}%-14s${NC}: ${WHITE}%s${NC}\n" "Local WAN"   "$lip"
        printf "  ${CYAN}%-14s${NC}: ${WHITE}%s${NC}\n" "Remote WAN"  "$rip"
        printf "  ${CYAN}%-14s${NC}: ${WHITE}%s${NC}\n" "Tunnel IP"   "${tun_l}/30"
        echo ""
        echo -e "  ${YELLOW}Test: ${NC}${GREEN}ping ${tun_r}${NC}"
    else
        p_err "GRE tunnel may have failed."
        ip link show "$tname" 2>/dev/null
    fi
    pause
}

# =============================================================================
# IPSEC TUNNEL
# =============================================================================

_ipsec_install() {
    local os
    os=$(detect_os)
    p_step "Installing StrongSwan (IPsec)..."
    case $os in
        ubuntu|debian)
            apt-get update -qq >/dev/null 2>&1
            apt-get install -y strongswan strongswan-pki \
                libcharon-extra-plugins >/dev/null 2>&1 ;;
        centos|rhel|rocky|almalinux)
            yum install -y epel-release >/dev/null 2>&1
            yum install -y strongswan >/dev/null 2>&1 ;;
        fedora) dnf install -y strongswan >/dev/null 2>&1 ;;
        *) p_err "Please install StrongSwan manually."; return 1 ;;
    esac
    command -v ipsec &>/dev/null \
        && p_ok "StrongSwan installed." \
        || { p_err "Installation failed."; return 1; }
}

configure_ipsec() {
    show_banner
    box "IPsec Tunnel — Configure  (StrongSwan)"

    echo -e "  ${DIM}IPsec provides strong encryption. Install StrongSwan on both servers.${NC}"
    echo ""

    command -v ipsec &>/dev/null || { _ipsec_install || { pause; return; }; }

    get_network_info
    local pub_ip
    pub_ip=$(get_public_ip)

    read -r -p "$(echo -e "  ${YELLOW}[1] Connection name (e.g. iran-kharej): ${NC}")" cname
    cname=$(clean_name "${cname:-tunnel1}")

    read -r -p "$(echo -e "  ${YELLOW}[2] This server public IP: ${NC}")" left_ip
    left_ip="${left_ip:-$pub_ip}"

    read -r -p "$(echo -e "  ${YELLOW}[3] Remote server public IP: ${NC}")" right_ip
    [ -z "$right_ip" ] && { p_err "Remote IP is required."; pause; return; }

    read -r -p "$(echo -e "  ${YELLOW}[4] This tunnel IP (e.g. 192.168.200.1): ${NC}")" left_tun
    left_tun="${left_tun:-192.168.200.1}"

    read -r -p "$(echo -e "  ${YELLOW}[5] Remote tunnel IP (e.g. 192.168.200.2): ${NC}")" right_tun
    right_tun="${right_tun:-192.168.200.2}"

    read -r -p "$(echo -e "  ${YELLOW}[6] Pre-Shared Key (blank = auto-generate): ${NC}")" psk
    if [ -z "$psk" ]; then
        psk=$(gen_key)
        echo -e "  ${GREEN}Auto-generated PSK: ${BOLD}${psk}${NC}"
    fi

    echo ""
    echo -e "  ${CYAN}IKE Encryption:${NC}"
    echo -e "  ${WHITE}[1]${NC} aes256gcm16-sha256-ecp256  ${DIM}(Modern — Recommended)${NC}"
    echo -e "  ${WHITE}[2]${NC} aes256-sha256-modp2048      ${DIM}(Compatible)${NC}"
    echo -e "  ${WHITE}[3]${NC} aes128-sha256-modp1024      ${DIM}(Fast)${NC}"
    echo ""
    read -r -p "  Choose [1-3] (default 1): " ike_ch
    local ike_alg esp_alg
    case "${ike_ch:-1}" in
        2) ike_alg="aes256-sha256-modp2048";    esp_alg="aes256-sha256"      ;;
        3) ike_alg="aes128-sha256-modp1024";    esp_alg="aes128-sha256"      ;;
        *) ike_alg="aes256gcm16-sha256-ecp256"; esp_alg="aes256gcm16-sha256" ;;
    esac

    mkdir -p "$CONFIG_DIR/ipsec"

    cat > /etc/ipsec.conf << EOF
# AVASH IPsec — ${cname}
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

conn ${cname}
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

    echo "${left_ip} ${right_ip} : PSK \"${psk}\"" > /etc/ipsec.secrets
    chmod 600 /etc/ipsec.secrets

    cp /etc/ipsec.conf "$CONFIG_DIR/ipsec/${cname}.conf"
    echo "$psk" > "$CONFIG_DIR/ipsec/${cname}.psk"
    chmod 600 "$CONFIG_DIR/ipsec/${cname}.psk"

    echo 1 > /proc/sys/net/ipv4/ip_forward
    sed -i '/net.ipv4.ip_forward/d' /etc/sysctl.conf
    echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf

    systemctl enable strongswan >/dev/null 2>&1
    systemctl restart strongswan 2>/dev/null \
        || systemctl restart ipsec 2>/dev/null \
        || ipsec start 2>/dev/null

    sleep 3
    echo ""
    p_ok "IPsec configured!"
    echo ""
    printf "  ${CYAN}%-14s${NC}: ${WHITE}%s${NC}\n" "Connection"   "$cname"
    printf "  ${CYAN}%-14s${NC}: ${WHITE}%s${NC}\n" "Left IP"      "$left_ip"
    printf "  ${CYAN}%-14s${NC}: ${WHITE}%s${NC}\n" "Right IP"     "$right_ip"
    printf "  ${CYAN}%-14s${NC}: ${WHITE}%s${NC}\n" "Tunnel IPs"   "${left_tun} ↔ ${right_tun}"
    printf "  ${CYAN}%-14s${NC}: ${WHITE}%s${NC}\n" "IKE"          "$ike_alg"
    echo ""
    echo -e "  ${YELLOW}PSK — copy this to the other server:${NC}"
    echo -e "  ${GREEN}${BOLD}${psk}${NC}"
    echo ""
    echo -e "  ${DIM}Check: ipsec status${NC}"
    pause
}

# =============================================================================
# SIT / 6in4 TUNNEL
# =============================================================================

configure_sit() {
    show_banner
    box "SIT / 6in4 Tunnel — Configure  (IPv6 over IPv4)"

    echo -e "  ${DIM}SIT tunnels carry IPv6 traffic over an IPv4 network.${NC}"
    echo ""

    get_network_info

    read -r -p "$(echo -e "  ${YELLOW}[1] Tunnel name (e.g. sit1): ${NC}")" sname
    sname=$(clean_name "${sname:-sit1}")

    read -r -p "$(echo -e "  ${YELLOW}[2] Local IPv4 (this server): ${NC}")" lip4
    lip4="${lip4:-$LOCAL_IP}"

    read -r -p "$(echo -e "  ${YELLOW}[3] Remote IPv4 (other server): ${NC}")" rip4
    [ -z "$rip4" ] && { p_err "Remote IP is required."; pause; return; }
    validate_ip "$rip4" || { p_err "Invalid IP address."; pause; return; }

    read -r -p "$(echo -e "  ${YELLOW}[4] Local IPv6 address (e.g. 2001:db8::1): ${NC}")" lip6
    lip6="${lip6:-2001:db8::1}"

    read -r -p "$(echo -e "  ${YELLOW}[5] IPv6 prefix length (default: 64): ${NC}")" pfx
    pfx="${pfx:-64}"

    read -r -p "$(echo -e "  ${YELLOW}[6] TTL (default: 64): ${NC}")" ttl
    ttl="${ttl:-64}"

    modprobe sit 2>/dev/null || true
    ip tunnel del "$sname" 2>/dev/null || true
    ip tunnel add "$sname" mode sit local "$lip4" remote "$rip4" ttl "$ttl"
    ip link set "$sname" up
    ip -6 addr add "${lip6}/${pfx}" dev "$sname"

    mkdir -p "$CONFIG_DIR/sit"
    printf 'TUNNEL_NAME="%s"\nLOCAL_IPV4="%s"\nREMOTE_IPV4="%s"\nLOCAL_IPV6="%s"\nIPV6_PREFIX="%s"\nTTL="%s"\n' \
        "$sname" "$lip4" "$rip4" "$lip6" "$pfx" "$ttl" \
        > "$CONFIG_DIR/sit/${sname}.conf"

    cat > "$SERVICE_DIR/avash-sit-${sname}.service" << EOF
[Unit]
Description=AVASH SIT Tunnel — ${sname}
After=network.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/bash -c 'modprobe sit; ip tunnel add ${sname} mode sit local ${lip4} remote ${rip4} ttl ${ttl}; ip link set ${sname} up; ip -6 addr add ${lip6}/${pfx} dev ${sname}'
ExecStop=/bin/bash -c 'ip tunnel del ${sname}'

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable "avash-sit-${sname}" >/dev/null 2>&1

    echo ""
    if ip link show "$sname" 2>/dev/null | grep -q "UP"; then
        p_ok "SIT Tunnel is active!"
        echo ""
        printf "  ${CYAN}%-14s${NC}: ${WHITE}%s${NC}\n" "Interface"   "$sname"
        printf "  ${CYAN}%-14s${NC}: ${WHITE}%s${NC}\n" "Local IPv4"  "$lip4"
        printf "  ${CYAN}%-14s${NC}: ${WHITE}%s${NC}\n" "Remote IPv4" "$rip4"
        printf "  ${CYAN}%-14s${NC}: ${WHITE}%s${NC}\n" "IPv6 Addr"   "${lip6}/${pfx}"
    else
        p_err "SIT tunnel may have failed."
    fi
    pause
}

# =============================================================================
# IPIP TUNNEL
# =============================================================================

configure_ipip() {
    show_banner
    box "IPIP Tunnel — Configure  (IP-in-IP)"

    echo -e "  ${DIM}IPIP encapsulates IPv4 inside IPv4. Lightweight, no encryption.${NC}"
    echo ""

    get_network_info

    read -r -p "$(echo -e "  ${YELLOW}[1] Tunnel name (e.g. ipip0): ${NC}")" iname
    iname=$(clean_name "${iname:-ipip0}")

    read -r -p "$(echo -e "  ${YELLOW}[2] Local IP (this server): ${NC}")" lip
    lip="${lip:-$LOCAL_IP}"

    read -r -p "$(echo -e "  ${YELLOW}[3] Remote IP (other server): ${NC}")" rip
    [ -z "$rip" ] && { p_err "Remote IP is required."; pause; return; }
    validate_ip "$rip" || { p_err "Invalid IP address."; pause; return; }

    read -r -p "$(echo -e "  ${YELLOW}[4] Tunnel local IP  (e.g. 10.10.0.1): ${NC}")" tun_l
    tun_l="${tun_l:-10.10.0.1}"

    read -r -p "$(echo -e "  ${YELLOW}[5] Tunnel remote IP (e.g. 10.10.0.2): ${NC}")" tun_r
    tun_r="${tun_r:-10.10.0.2}"

    read -r -p "$(echo -e "  ${YELLOW}[6] TTL (default: 64): ${NC}")" ttl
    ttl="${ttl:-64}"

    modprobe ipip 2>/dev/null || true
    ip tunnel del "$iname" 2>/dev/null || true
    ip tunnel add "$iname" mode ipip local "$lip" remote "$rip" ttl "$ttl"
    ip link set "$iname" up
    ip addr add "${tun_l}/30" dev "$iname"
    ip link set "$iname" mtu 1480

    mkdir -p "$CONFIG_DIR/ipip"
    printf 'TUNNEL_NAME="%s"\nLOCAL_IP="%s"\nREMOTE_IP="%s"\nTUN_LOCAL="%s"\nTUN_REMOTE="%s"\nTTL="%s"\n' \
        "$iname" "$lip" "$rip" "$tun_l" "$tun_r" "$ttl" \
        > "$CONFIG_DIR/ipip/${iname}.conf"

    cat > "$SERVICE_DIR/avash-ipip-${iname}.service" << EOF
[Unit]
Description=AVASH IPIP Tunnel — ${iname}
After=network.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/bash -c 'modprobe ipip; ip tunnel add ${iname} mode ipip local ${lip} remote ${rip} ttl ${ttl}; ip link set ${iname} up; ip addr add ${tun_l}/30 dev ${iname}; ip link set ${iname} mtu 1480'
ExecStop=/bin/bash -c 'ip tunnel del ${iname}'

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable "avash-ipip-${iname}" >/dev/null 2>&1

    echo ""
    if ip link show "$iname" 2>/dev/null | grep -q "UP"; then
        p_ok "IPIP Tunnel is active!"
        echo ""
        printf "  ${CYAN}%-14s${NC}: ${WHITE}%s${NC}\n" "Interface"   "$iname"
        printf "  ${CYAN}%-14s${NC}: ${WHITE}%s${NC}\n" "Local WAN"   "$lip"
        printf "  ${CYAN}%-14s${NC}: ${WHITE}%s${NC}\n" "Remote WAN"  "$rip"
        printf "  ${CYAN}%-14s${NC}: ${WHITE}%s${NC}\n" "Tunnel IP"   "${tun_l}/30"
        echo ""
        echo -e "  ${YELLOW}Test: ${NC}${GREEN}ping ${tun_r}${NC}"
    else
        p_err "IPIP tunnel may have failed."
    fi
    pause
}

# =============================================================================
# PROTOCOL SELECTOR
# =============================================================================

_proto_menu() {
    # Sets global PROTO_CHOICE
    local title="$1"
    show_banner
    box "$title"
    echo -e "  ${WHITE}[1]${NC}  🚀 KCP         ${DIM}— Raw packet, anti-censorship, anti-QoS${NC}"
    echo -e "  ${WHITE}[2]${NC}  🔒 WireGuard   ${DIM}— Modern VPN, fastest, encrypted${NC}"
    echo -e "  ${WHITE}[3]${NC}  🌐 GRE         ${DIM}— Generic encapsulation, site-to-site${NC}"
    echo -e "  ${WHITE}[4]${NC}  🛡  IPsec       ${DIM}— Most secure, encrypted, IKEv2${NC}"
    echo -e "  ${WHITE}[5]${NC}  📡 SIT / 6in4  ${DIM}— IPv6 over IPv4${NC}"
    echo -e "  ${WHITE}[6]${NC}  ⚡ IPIP        ${DIM}— Lightest encapsulation${NC}"
    echo ""
    echo -e "  ${WHITE}[0]${NC}  ↩  Back to Main Menu"
    echo ""
    read -r -p "  Choose [0-6]: " PROTO_CHOICE
}

configure_server() {
    while true; do
        _proto_menu "Configure Server  (Abroad / Kharej)"
        case "$PROTO_CHOICE" in
            1) configure_kcp_server       ;;
            2) configure_wireguard_server ;;
            3) configure_gre              ;;
            4) configure_ipsec            ;;
            5) configure_sit              ;;
            6) configure_ipip             ;;
            0) return ;;
            *) p_err "Invalid choice."; sleep 1 ;;
        esac
    done
}

configure_client() {
    while true; do
        _proto_menu "Configure Client  (Iran / Domestic)"
        case "$PROTO_CHOICE" in
            1) configure_kcp_client       ;;
            2) configure_wireguard_client ;;
            3) configure_gre              ;;
            4) configure_ipsec            ;;
            5) configure_sit              ;;
            6) configure_ipip             ;;
            0) return ;;
            *) p_err "Invalid choice."; sleep 1 ;;
        esac
    done
}

# =============================================================================
# SERVICE MANAGER
# =============================================================================

manage_services() {
    while true; do
        show_banner
        box "Service Manager"

        local services=()
        mapfile -t services < <(get_all_services)

        if [ "${#services[@]}" -eq 0 ]; then
            echo -e "  ${YELLOW}No AVASH tunnel services found.${NC}"
            echo ""
            pause
            return
        fi

        echo -e "  ${CYAN}┌─────┬──────────────────────────────────────┬────────────┬──────────────┐${NC}"
        echo -e "  ${CYAN}│  #  │ Service Name                         │ Status     │ Auto-Restart │${NC}"
        echo -e "  ${CYAN}├─────┼──────────────────────────────────────┼────────────┼──────────────┤${NC}"

        local i=1
        for svc in "${services[@]}"; do
            local st col cron_st
            st=$(systemctl is-active "$svc" 2>/dev/null || echo "unknown")
            crontab -l 2>/dev/null | grep -q "restart ${svc%.service}" \
                && cron_st="Yes" || cron_st="No"
            case "$st" in
                active)   col="${GREEN}"  ;;
                failed)   col="${RED}"    ;;
                inactive) col="${YELLOW}" ;;
                *)        col="${WHITE}"  ;;
            esac
            printf "  ${CYAN}│${NC} %3d ${CYAN}│${NC} %-36s ${CYAN}│${NC} ${col}%-10s${NC} ${CYAN}│${NC} %-12s ${CYAN}│${NC}\n" \
                "$i" "${svc%.service}" "$st" "$cron_st"
            ((i++))
        done
        echo -e "  ${CYAN}└─────┴──────────────────────────────────────┴────────────┴──────────────┘${NC}"
        echo ""
        echo -e "  ${WHITE}[0]${NC} ↩  Back   ${DIM}|${NC}  Enter number to manage"
        echo ""
        read -r -p "  Choose [0-${#services[@]}]: " ch

        [ "$ch" = "0" ] && return
        if [[ "$ch" =~ ^[0-9]+$ ]] && [ "$ch" -ge 1 ] && [ "$ch" -le "${#services[@]}" ]; then
            _manage_single "${services[$((ch-1))]}"
        else
            p_err "Invalid choice."
            sleep 1
        fi
    done
}

_manage_single() {
    local svc="$1"
    local name="${svc%.service}"

    while true; do
        show_banner
        box "Managing: ${name}"

        local st
        st=$(systemctl is-active "$svc" 2>/dev/null || echo "unknown")
        case "$st" in
            active)   echo -e "  Status : ${GREEN}🟢 Running${NC}"  ;;
            failed)   echo -e "  Status : ${RED}🔴 Failed${NC}"     ;;
            inactive) echo -e "  Status : ${YELLOW}🟡 Stopped${NC}" ;;
            *)        echo -e "  Status : ${WHITE}⚪ Unknown${NC}"   ;;
        esac

        local cronline
        cronline=$(crontab -l 2>/dev/null | grep "restart ${name}" | head -1)
        echo -e "  Cron   : ${DIM}${cronline:-none}${NC}"
        echo ""
        echo -e "  ${WHITE}[1]${NC}  ▶  Start"
        echo -e "  ${WHITE}[2]${NC}  ■  Stop"
        echo -e "  ${WHITE}[3]${NC}  ↺  Restart"
        echo -e "  ${WHITE}[4]${NC}  📊 Status details"
        echo -e "  ${WHITE}[5]${NC}  📝 View logs  (last 40 lines)"
        echo -e "  ${WHITE}[6]${NC}  ⏰ Auto-restart (cron)"
        echo -e "  ${WHITE}[7]${NC}  🗑  Delete service"
        echo -e "  ${WHITE}[0]${NC}  ↩  Back"
        echo ""
        read -r -p "  Choose [0-7]: " ac

        case "$ac" in
            1) systemctl start   "$svc" && p_ok "Started."   || p_err "Failed."; sleep 1 ;;
            2) systemctl stop    "$svc" && p_ok "Stopped."   || p_err "Failed."; sleep 1 ;;
            3) systemctl restart "$svc" && p_ok "Restarted." || p_err "Failed."; sleep 1 ;;
            4) echo ""; systemctl status "$svc" --no-pager -l; pause ;;
            5) echo ""; journalctl -u "$svc" -n 40 --no-pager; pause ;;
            6) _cron_menu "$name" ;;
            7) _delete_service "$svc"; pause; return ;;
            0) return ;;
            *) p_err "Invalid choice."; sleep 1 ;;
        esac
    done
}

_cron_menu() {
    local name="$1"
    while true; do
        show_banner
        box "Auto-Restart — ${name}"

        local cur
        cur=$(crontab -l 2>/dev/null | grep "restart ${name}" | head -1)
        echo -e "  Current: ${DIM}${cur:-none}${NC}"
        echo ""
        line
        local i=1 interval_keys=()
        for interval in "${!CRON_INTERVALS[@]}"; do
            interval_keys+=("$interval")
            echo -e "  ${WHITE}[${i}]${NC}  Every ${interval}"
            ((i++))
        done
        echo -e "  ${WHITE}[${i}]${NC}  Remove auto-restart"
        echo -e "  ${WHITE}[0]${NC}  ↩  Back"
        echo ""
        read -r -p "  Choose: " cc

        [ "$cc" = "0" ] && return
        if [ "$cc" = "$i" ]; then
            crontab -l 2>/dev/null | grep -v "restart ${name}" | crontab -
            p_ok "Auto-restart removed."
            pause
            return
        elif [[ "$cc" =~ ^[0-9]+$ ]] && [ "$cc" -ge 1 ] && [ "$cc" -lt "$i" ]; then
            local sel_interval="${interval_keys[$((cc-1))]}"
            local cron_cmd="systemctl restart ${name}"
            (crontab -l 2>/dev/null | grep -v "$cron_cmd"; \
                echo "${CRON_INTERVALS[$sel_interval]} $cron_cmd") | crontab -
            p_ok "Auto-restart set: every ${sel_interval}."
            pause
            return
        else
            p_err "Invalid choice."
            sleep 1
        fi
    done
}

_delete_service() {
    local svc="$1"
    local name="${svc%.service}"
    echo ""
    read -r -p "$(echo -e "  ${RED}Delete '${name}'? This cannot be undone. (y/N): ${NC}")" cf
    [[ "$cf" =~ ^[Yy]$ ]] || return
    crontab -l 2>/dev/null | grep -v "restart ${name}" | crontab - 2>/dev/null || true
    systemctl stop    "$svc" 2>/dev/null || true
    systemctl disable "$svc" 2>/dev/null || true
    rm -f "$SERVICE_DIR/$svc"
    systemctl daemon-reload 2>/dev/null || true
    p_ok "Service '${name}' deleted."
}

# =============================================================================
# DEPENDENCIES
# =============================================================================

install_dependencies() {
    show_banner
    box "Install Dependencies"

    local os
    os=$(detect_os)
    p_step "Detected OS: ${os}"

    case $os in
        ubuntu|debian)
            apt-get update -qq >/dev/null 2>&1
            DEBIAN_FRONTEND=noninteractive apt-get install -y \
                curl wget iptables iptables-persistent netfilter-persistent \
                lsof iproute2 cron dnsutils libpcap-dev net-tools \
                >/dev/null 2>&1 ;;
        centos|rhel|rocky|almalinux)
            yum install -y curl wget iptables-services lsof iproute \
                cronie bind-utils libpcap-devel net-tools \
                >/dev/null 2>&1
            systemctl enable iptables >/dev/null 2>&1 ;;
        fedora)
            dnf install -y curl wget iptables lsof iproute cronie \
                bind-utils libpcap-devel >/dev/null 2>&1 ;;
        *)
            p_warn "Unknown OS. Install manually: curl wget iptables lsof iproute2" ;;
    esac

    sed -i '/net.ipv4.ip_forward/d' /etc/sysctl.conf
    echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
    sysctl -p >/dev/null 2>&1

    mkdir -p "$CONFIG_DIR" "$LOG_DIR" "$BACKUP_DIR"
    p_ok "Dependencies installed."
    pause
}

install_manager_script() {
    p_step "Installing manager to ${MANAGER_PATH}..."
    local src="${BASH_SOURCE[0]}"
    [ -z "$src" ] || [ "$src" = "$0" ] && src="$0"
    cp -f "$src" "$MANAGER_PATH"
    chmod +x "$MANAGER_PATH"
    p_ok "Manager installed! Run: ${GREEN}${MANAGER_NAME}${NC}"
}

# =============================================================================
# SERVER OPTIMIZATION
# =============================================================================

optimize_server() {
    show_banner
    box "Server Optimization"

    mkdir -p "$BACKUP_DIR"
    cp /etc/sysctl.conf "$BACKUP_DIR/sysctl-$(date +%Y%m%d-%H%M%S).bak" 2>/dev/null || true

    p_step "Applying kernel optimizations..."

    cat > /etc/sysctl.d/99-avash-tunnel.conf << 'SYSCTL_EOF'
# AVASH Tunnel Optimization
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1

# Socket buffers (64 MB)
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
net.core.rmem_default = 1048576
net.core.wmem_default = 1048576
net.core.optmem_max = 65536
net.core.netdev_max_backlog = 65536

# TCP tuning
net.ipv4.tcp_rmem = 4096 1048576 33554432
net.ipv4.tcp_wmem = 4096 524288 16777216
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_mtu_probing = 1

# UDP (for KCP / WireGuard)
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
SYSCTL_EOF

    sysctl -p /etc/sysctl.d/99-avash-tunnel.conf >/dev/null 2>&1

    lsmod | grep -q tcp_bbr || {
        modprobe tcp_bbr 2>/dev/null || true
        echo "tcp_bbr" >> /etc/modules-load.d/modules.conf 2>/dev/null || true
    }

    cat > /etc/security/limits.d/99-avash.conf << 'LIMITS_EOF'
*    soft nofile 1048576
*    hard nofile 1048576
root soft nofile 1048576
root hard nofile 1048576
LIMITS_EOF

    p_ok "Optimization complete!"
    echo ""
    echo -e "  ${GREEN}✓${NC}  TCP BBR congestion control enabled"
    echo -e "  ${GREEN}✓${NC}  Socket buffers: 64 MB"
    echo -e "  ${GREEN}✓${NC}  IP forwarding enabled"
    echo -e "  ${GREEN}✓${NC}  TCP FastOpen enabled"
    echo -e "  ${GREEN}✓${NC}  Connection tracking tuned"
    echo -e "  ${GREEN}✓${NC}  File descriptors: 1,048,576"
    echo -e "  ${GREEN}✓${NC}  UDP buffers optimized for KCP/WireGuard"
    pause
}

# =============================================================================
# CONNECTION TESTING
# =============================================================================

test_connection() {
    while true; do
        show_banner
        box "Connection Testing"

        echo -e "  ${WHITE}[1]${NC}  Ping + MTU Test"
        echo -e "  ${WHITE}[2]${NC}  Internet Connectivity"
        echo -e "  ${WHITE}[3]${NC}  DNS Resolution"
        echo -e "  ${WHITE}[4]${NC}  All Tunnel Status"
        echo ""
        echo -e "  ${WHITE}[0]${NC}  ↩  Back"
        echo ""
        read -r -p "  Choose [0-4]: " tc

        case "$tc" in
            1) _test_ping_mtu   ;;
            2) _test_internet   ;;
            3) _test_dns        ;;
            4) _test_all_status ;;
            0) return ;;
            *) p_err "Invalid choice."; sleep 1 ;;
        esac
    done
}

_test_ping_mtu() {
    echo ""
    read -r -p "  Remote server IP: " rip
    [ -z "$rip" ] && return
    validate_ip "$rip" || { p_err "Invalid IP address."; pause; return; }

    echo ""
    echo -e "  ${CYAN}Ping test → ${rip}:${NC}"
    local result loss avg
    result=$(ping -c 5 -W 2 "$rip" 2>&1)
    if echo "$result" | grep -q "transmitted"; then
        loss=$(echo "$result" | grep -o '[0-9]*% packet loss' | grep -o '[0-9]*')
        avg=$(echo "$result" | grep rtt | awk -F'/' '{print $5}')
        echo -e "  Packet loss : ${loss:-?}%"
        echo -e "  Avg RTT     : ${avg:-?} ms"
        [ "${loss:-100}" -le 5  ] && echo -e "  ${GREEN}[+] EXCELLENT${NC}"
        [ "${loss:-100}" -gt 5  ] && [ "${loss:-100}" -le 20 ] && echo -e "  ${YELLOW}[!] FAIR${NC}"
        [ "${loss:-100}" -gt 20 ] && echo -e "  ${RED}[-] POOR${NC}"
    else
        echo -e "  ${RED}[-] Ping failed${NC}"
    fi

    echo ""
    echo -e "  ${CYAN}MTU Discovery:${NC}"
    local best_mtu="N/A"
    for mtu in "${MTU_SIZES[@]}"; do
        local ps=$((mtu - 28))
        [ $ps -lt 0 ] && continue
        printf "  MTU %4s : " "$mtu"
        local pr
        pr=$(ping -c 3 -W 1 -M do -s "$ps" "$rip" 2>&1)
        if echo "$pr" | grep -qE "3 received|3 packets received"; then
            echo -e "${GREEN}OK${NC}"
            best_mtu="$mtu"
            break
        elif echo "$pr" | grep -q "transmitted"; then
            local r
            r=$(echo "$pr" | grep transmitted | awk '{print $4}')
            if [ "${r:-0}" -gt 0 ]; then
                echo -e "${YELLOW}PARTIAL (${r}/3)${NC}"
                best_mtu="$mtu"
            else
                echo -e "${RED}FAIL${NC}"
            fi
        else
            echo -e "${RED}FAIL${NC}"
        fi
    done
    echo ""
    echo -e "  ${GREEN}Recommended MTU: ${best_mtu}${NC}"
    pause
}

_test_internet() {
    echo ""
    echo -e "  ${CYAN}Internet Connectivity:${NC}"
    echo ""
    local ok=0
    for url in "https://google.com" "https://github.com" "https://cloudflare.com"; do
        printf "  %-34s: " "$url"
        curl -s --max-time 4 "$url" >/dev/null 2>&1 \
            && { echo -e "${GREEN}OK${NC}"; ((ok++)); } \
            || echo -e "${RED}Failed${NC}"
    done
    echo ""
    [ "$ok" -ge 2 ] \
        && p_ok "Internet connectivity: Working" \
        || p_err "Internet connectivity: Limited or blocked"
    pause
}

_test_dns() {
    echo ""
    echo -e "  ${CYAN}DNS Resolution:${NC}"
    echo ""
    for dns in "${DNS_LIST[@]}"; do
        printf "  DNS %-18s: " "$dns"
        timeout 3 dig +short google.com "@$dns" >/dev/null 2>&1 \
            && echo -e "${GREEN}OK${NC}" \
            || echo -e "${RED}Failed${NC}"
    done
    printf "  %-22s: " "System DNS"
    timeout 3 nslookup google.com >/dev/null 2>&1 \
        && echo -e "${GREEN}OK${NC}" \
        || echo -e "${RED}Failed${NC}"
    pause
}

_test_all_status() {
    echo ""
    echo -e "  ${CYAN}WireGuard:${NC}"
    if command -v wg &>/dev/null; then
        local out
        out=$(wg show 2>/dev/null | grep -E "interface|endpoint|transfer")
        [ -n "$out" ] && echo "$out" | sed 's/^/  /' || echo "  none"
    else
        echo "  not installed"
    fi

    echo ""
    echo -e "  ${CYAN}Kernel Tunnels (GRE / IPIP / SIT):${NC}"
    ip tunnel show 2>/dev/null | grep -v "any/any" \
        | sed 's/^/  /' || echo "  none"

    echo ""
    echo -e "  ${CYAN}IPsec:${NC}"
    if command -v ipsec &>/dev/null; then
        ipsec status 2>/dev/null | head -8 | sed 's/^/  /' || echo "  not running"
    else
        echo "  not installed"
    fi

    echo ""
    echo -e "  ${CYAN}AVASH Services:${NC}"
    local found=0
    while IFS= read -r svc; do
        [ -z "$svc" ] && continue
        local st col
        st=$(systemctl is-active "$svc" 2>/dev/null || echo "unknown")
        [ "$st" = "active" ] && col="$GREEN" || col="$RED"
        printf "  %-44s ${col}%s${NC}\n" "${svc%.service}" "$st"
        found=1
    done < <(get_all_services)
    [ "$found" -eq 0 ] && echo "  none"
    pause
}

# =============================================================================
# TELEGRAM BOT
# =============================================================================

BOT_CONFIG_FILE="$CONFIG_DIR/bot.conf"

_load_bot() {
    BOT_TOKEN="" CHAT_ID="" BOT_ENABLED="false"
    [ -f "$BOT_CONFIG_FILE" ] && . "$BOT_CONFIG_FILE"
}

_save_bot() {
    mkdir -p "$CONFIG_DIR"
    cat > "$BOT_CONFIG_FILE" << EOF
BOT_TOKEN="${BOT_TOKEN}"
CHAT_ID="${CHAT_ID}"
BOT_ENABLED="${BOT_ENABLED}"
EOF
    chmod 600 "$BOT_CONFIG_FILE"
}

_send_tg() {
    [ -z "$BOT_TOKEN" ] || [ -z "$CHAT_ID" ] && return 1
    curl -s --max-time 10 \
        -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        -d "chat_id=${CHAT_ID}&text=${1}&parse_mode=HTML" >/dev/null 2>&1
}

telegram_bot_menu() {
    _load_bot
    while true; do
        show_banner
        box "Telegram Bot"

        local stat_label
        [ "$BOT_ENABLED" = "true" ] \
            && stat_label="${GREEN}Enabled${NC}" \
            || stat_label="${RED}Disabled${NC}"

        echo -e "  Status  : $(echo -e "$stat_label")"
        echo -e "  Token   : ${CYAN}${BOT_TOKEN:0:20}${BOT_TOKEN:+...}${NC}"
        echo -e "  Chat ID : ${CYAN}${CHAT_ID:-Not set}${NC}"
        echo ""
        echo -e "  ${WHITE}[1]${NC}  Setup bot  (token + chat ID)"
        echo -e "  ${WHITE}[2]${NC}  Enable / Disable"
        echo -e "  ${WHITE}[3]${NC}  Send test message"
        echo ""
        echo -e "  ${WHITE}[0]${NC}  ↩  Back"
        echo ""
        read -r -p "  Choose [0-3]: " bc

        case "$bc" in
            1)
                echo ""
                read -r -p "  Bot Token : " BOT_TOKEN
                read -r -p "  Chat ID   : " CHAT_ID
                BOT_ENABLED="true"
                _save_bot
                p_ok "Bot configured."
                sleep 1
                ;;
            2)
                [ "$BOT_ENABLED" = "true" ] && BOT_ENABLED="false" || BOT_ENABLED="true"
                _save_bot
                p_ok "Bot: $([ "$BOT_ENABLED" = "true" ] && echo "Enabled" || echo "Disabled")"
                sleep 1
                ;;
            3)
                if [ -n "$BOT_TOKEN" ] && [ -n "$CHAT_ID" ]; then
                    local hn pub
                    hn=$(hostname 2>/dev/null || echo "server")
                    pub=$(get_public_ip)
                    local msg
                    msg="✅ <b>AVASH Tunnel Bot</b>%0AServer: ${hn}%0AIP: ${pub}%0ATime: $(date '+%Y-%m-%d %H:%M:%S')"
                    _send_tg "$msg" \
                        && p_ok "Test message sent! Check your Telegram." \
                        || p_err "Failed. Check token and chat ID."
                else
                    p_err "Configure the bot first (option 1)."
                fi
                pause
                ;;
            0) return ;;
            *) p_err "Invalid choice."; sleep 1 ;;
        esac
    done
}

# =============================================================================
# UNINSTALL
# =============================================================================

uninstall_all() {
    show_banner
    box "Uninstall AVASH Tunnel Manager"

    echo -e "  ${RED}The following will be removed:${NC}"
    echo -e "  • All tunnel services"
    echo -e "  • All configs in ${CONFIG_DIR}"
    echo -e "  • Paqet binary"
    echo -e "  • Kernel optimizations"
    echo -e "  • Manager script"
    echo ""
    read -r -p "  Type 'yes' to confirm: " cf
    [ "$cf" != "yes" ] && { p_info "Cancelled."; pause; return; }

    p_step "Stopping and removing services..."
    while IFS= read -r svc; do
        [ -z "$svc" ] && continue
        crontab -l 2>/dev/null | grep -v "restart ${svc%.service}" | crontab - 2>/dev/null || true
        systemctl stop    "$svc" 2>/dev/null || true
        systemctl disable "$svc" 2>/dev/null || true
        rm -f "$SERVICE_DIR/$svc"
    done < <(get_all_services)
    systemctl daemon-reload 2>/dev/null || true

    p_step "Removing WireGuard interfaces..."
    if command -v wg &>/dev/null; then
        for iface in $(wg show interfaces 2>/dev/null); do
            wg-quick down "$iface" 2>/dev/null || true
        done
    fi

    p_step "Removing kernel tunnels..."
    ip tunnel show 2>/dev/null | awk -F: '{print $1}' | while read -r t; do
        [[ "$t" =~ ^(gre|ipip|sit) ]] && ip tunnel del "$t" 2>/dev/null || true
    done

    p_step "Removing files..."
    rm -rf "$CONFIG_DIR" "$LOG_DIR"
    rm -f  "$MANAGER_PATH"
    rm -f  "$BIN_DIR/paqet"
    rm -rf /opt/paqet
    rm -f  /etc/sysctl.d/99-avash-tunnel.conf
    rm -f  /etc/security/limits.d/99-avash.conf

    p_ok "AVASH Tunnel Manager has been removed."
    pause
    exit 0
}

# =============================================================================
# MAIN MENU
# =============================================================================

main_menu() {
    while true; do
        show_banner

        # Status bar
        local total=0 active=0
        while IFS= read -r svc; do
            [ -z "$svc" ] && continue
            ((total++))
            systemctl is-active --quiet "$svc" 2>/dev/null && ((active++)) || true
        done < <(get_all_services)

        local paqet_label wg_label
        [ -f "$BIN_DIR/paqet" ] \
            && paqet_label="${GREEN}Installed${NC}" \
            || paqet_label="${YELLOW}Not installed${NC}"
        command -v wg &>/dev/null \
            && wg_label="${GREEN}Installed${NC}" \
            || wg_label="${DIM}Not installed${NC}"

        echo -e "  ${CYAN}Tunnels   ${NC}: ${GREEN}${active} active${NC} / ${total} total"
        echo -e "  ${CYAN}Paqet     ${NC}: $(echo -e "$paqet_label")"
        echo -e "  ${CYAN}WireGuard ${NC}: $(echo -e "$wg_label")"
        echo ""
        line
        echo -e "  ${WHITE}[1]${NC}  📦 Install / Update Paqet Core"
        echo -e "  ${WHITE}[2]${NC}  ⚙️  Install Dependencies & Manager"
        line
        echo -e "  ${WHITE}[3]${NC}  🖥️  Configure Server   ${DIM}(Abroad / Kharej)${NC}"
        echo -e "  ${WHITE}[4]${NC}  🇮🇷 Configure Client   ${DIM}(Iran / Domestic)${NC}"
        line
        echo -e "  ${WHITE}[5]${NC}  🛠️  Manage Services"
        echo -e "  ${WHITE}[6]${NC}  📊 Test Connection"
        echo -e "  ${WHITE}[7]${NC}  🚀 Optimize Server"
        echo -e "  ${WHITE}[8]${NC}  🤖 Telegram Bot"
        echo -e "  ${WHITE}[9]${NC}  🗑️  Uninstall All"
        line
        echo -e "  ${WHITE}[0]${NC}  🚪 Exit"
        echo ""
        read -r -p "  Select option [0-9]: " choice

        case "$choice" in
            1) install_paqet_menu                    ;;
            2) install_dependencies; install_manager_script ;;
            3) configure_server                      ;;
            4) configure_client                      ;;
            5) manage_services                       ;;
            6) test_connection                       ;;
            7) optimize_server                       ;;
            8) telegram_bot_menu                     ;;
            9) uninstall_all                         ;;
            0)
                echo ""
                echo -e "  ${GREEN}Goodbye!  Telegram: ${TELEGRAM_CHANNEL}${NC}"
                echo ""
                exit 0
                ;;
            *) p_err "Invalid option."; sleep 1 ;;
        esac
    done
}

# =============================================================================
# ENTRY POINT
# =============================================================================

check_root
mkdir -p "$CONFIG_DIR" "$LOG_DIR" "$BACKUP_DIR" 2>/dev/null || true
BOT_CONFIG_FILE="$CONFIG_DIR/bot.conf"
main_menu
