#!/usr/bin/env bash

# Remote Host Diagnostics Script for Lightsail Proxy
# Usage: ./diagnose_host.sh -i <ip_address> -k <ssh_key_path> [-u <username>]

set -euo pipefail

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color/Reset
BOLD='\033[1m'

show_usage() {
    cat <<EOF
Usage: $(basename "$0") -i <ip_address> -k <ssh_key_path> [-u <username>]

Options:
  -i, --ip     IP address of the remote host (Required)
  -k, --key    Path to the SSH private key (Required)
  -u, --user   SSH username (Optional, default: ubuntu)
  -h, --help   Show this help message
EOF
}

IP=""
KEY_PATH=""
USER="ubuntu"

while [[ $# -gt 0 ]]; do
    case "$1" in
        -i|--ip)
            IP="$2"
            shift 2
            ;;
        -k|--key)
            KEY_PATH="$2"
            shift 2
            ;;
        -u|--user)
            USER="$2"
            shift 2
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            echo -e "${RED}Error: Unknown option $1${NC}" >&2
            show_usage
            exit 1
            ;;
    esac
done

if [[ -z "$IP" ]]; then
    echo -e "${RED}Error: Missing required option -i / --ip${NC}" >&2
    show_usage
    exit 1
fi

if [[ -z "$KEY_PATH" ]]; then
    echo -e "${RED}Error: Missing required option -k / --key${NC}" >&2
    show_usage
    exit 1
fi

# Expand tilde (~) manually in Bash if path begins with it
if [[ "$KEY_PATH" == \~* ]]; then
    KEY_PATH="${KEY_PATH/\~/$HOME}"
fi

if [[ ! -f "$KEY_PATH" ]]; then
    echo -e "${RED}Error: Private key file not found at '$KEY_PATH'${NC}" >&2
    exit 1
fi

echo -e "${BLUE}=== Starting Diagnostics for $USER@$IP ===${NC}"

# Define the SSH connection prefix
SSH_CMD="ssh -i $KEY_PATH -o StrictHostKeyChecking=no -o ConnectTimeout=5 $USER@$IP"

# Test SSH connection
if ! $SSH_CMD "true" 2>/dev/null; then
    echo -e "${RED}Error: Failed to connect to $USER@$IP via SSH.${NC}" >&2
    exit 1
fi

# Run diagnostics
echo -e "\n${BOLD}${CYAN}[1/5] Host Information & Uptime${NC}"
$SSH_CMD "echo -n 'Uptime: '; uptime; echo -n 'Date/Timezone: '; date; timedatectl | grep 'Time zone'"

echo -e "\n${BOLD}${CYAN}[2/5] Memory & Swap Space${NC}"
$SSH_CMD "free -h"
echo ""
$SSH_CMD "swapon --show" || echo -e "${RED}Warning: No swap space configured!${NC}"

echo -e "\n${BOLD}${CYAN}[3/5] Top Memory Consuming Processes${NC}"
$SSH_CMD "ps aux --sort=-%mem | head -n 6"

echo -e "\n${BOLD}${CYAN}[4/5] Docker & Container Status${NC}"
if $SSH_CMD "command -v docker >/dev/null 2>&1"; then
    $SSH_CMD "docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'"
    echo ""
    $SSH_CMD "docker stats --no-stream --format 'table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}'"
else
    echo -e "${YELLOW}Docker is not installed on the remote host.${NC}"
fi

echo -e "\n${BOLD}${CYAN}[5/5] OOM (Out of Memory) Events${NC}"
# Check both system journal and dmesg
OOM_LOGS=$($SSH_CMD "sudo journalctl -k -g 'Out of memory' -n 10 --no-pager 2>/dev/null || sudo dmesg -T | grep -i 'oom' | tail -n 10 || true")

if [[ -z "$OOM_LOGS" ]]; then
    echo -e "${GREEN}No recent Out of Memory (OOM) events detected in kernel logs.${NC}"
else
    echo -e "${RED}Recent OOM events detected!:${NC}"
    echo "$OOM_LOGS"
fi

echo -e "\n${BLUE}=== Diagnostics Completed ===${NC}"
