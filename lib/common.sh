#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# common.sh - Shared utility functions for hardening scripts
# ============================================================

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Globals (set by harden.sh)
DRY_RUN="${DRY_RUN:-false}"
ROLLBACK_LOG="${ROLLBACK_LOG:-/var/log/hardening/rollback-$(date +%Y%m%d-%H%M%S).log}"
BACKUP_DIR="${BACKUP_DIR:-/var/log/hardening/backups}"
SCRIPT_DIR="${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
CONFIG_FILE="${CONFIG_FILE:-${SCRIPT_DIR}/config.yml}"

# --------------------------------------------------------------
# log_change - Record a change for rollback
# Usage: log_change "description" "rollback_command"
# --------------------------------------------------------------
log_change() {
    local description="$1"
    local rollback_cmd="${2:-}"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    echo "[${timestamp}] ${description} | ROLLBACK: ${rollback_cmd}" >> "${ROLLBACK_LOG}"
    print_status "CHANGED" "${description}"
}

# --------------------------------------------------------------
# backup_file - Create a backup of a file before modifying it
# Usage: backup_file /path/to/file
# --------------------------------------------------------------
backup_file() {
    local file="$1"
    if [[ ! -f "${file}" ]]; then
        print_warning "File ${file} does not exist, skipping backup"
        return 0
    fi
    local backup_path="${BACKUP_DIR}${file}.$(date +%Y%m%d-%H%M%S).bak"
    mkdir -p "$(dirname "${backup_path}")"
    cp -a "${file}" "${backup_path}"
    log_change "Backed up ${file}" "cp -a ${backup_path} ${file}"
}

# --------------------------------------------------------------
# parse_config - Read a value from config.yml
# Usage: value=$(parse_config "key_name")
# Supports simple flat YAML: key: value
# Arrays like [a, b, c] are returned space-separated
# --------------------------------------------------------------
parse_config() {
    local key="$1"
    local value
    value=$(grep -E "^${key}:" "${CONFIG_FILE}" | head -1 | sed "s/^${key}:[[:space:]]*//" | sed 's/[[:space:]]*$//')

    # Handle array notation [val1, val2]
    if [[ "${value}" =~ ^\[.*\]$ ]]; then
        value=$(echo "${value}" | tr -d '[]' | tr ',' '\n' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
    fi

    # Handle empty string
    if [[ "${value}" == '""' || "${value}" == "''" ]]; then
        value=""
    fi

    echo "${value}"
}

# --------------------------------------------------------------
# check_root - Ensure the script is running as root
# --------------------------------------------------------------
check_root() {
    if [[ "$(id -u)" -ne 0 ]]; then
        print_error "This script must be run as root. Use: sudo $0"
        exit 1
    fi
}

# --------------------------------------------------------------
# dry_run_msg - Print what would be done in dry-run mode
# Returns 0 if dry run (caller should skip), 1 if not dry run
# Usage: dry_run_msg "Would disable root login" && return
# --------------------------------------------------------------
dry_run_msg() {
    local msg="$1"
    if [[ "${DRY_RUN}" == "true" ]]; then
        echo -e "${YELLOW}[DRY-RUN]${NC} ${msg}"
        return 0
    fi
    return 1
}

# --------------------------------------------------------------
# Print helpers
# --------------------------------------------------------------
print_status() {
    local status="$1"
    local msg="$2"
    case "${status}" in
        OK|CHANGED)
            echo -e "${GREEN}[${status}]${NC} ${msg}" ;;
        SKIP)
            echo -e "${BLUE}[${status}]${NC} ${msg}" ;;
        WARNING)
            echo -e "${YELLOW}[${status}]${NC} ${msg}" ;;
        ERROR)
            echo -e "${RED}[${status}]${NC} ${msg}" ;;
        *)
            echo "[${status}] ${msg}" ;;
    esac
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_ok() {
    echo -e "${GREEN}[OK]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_section() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}========================================${NC}"
}
