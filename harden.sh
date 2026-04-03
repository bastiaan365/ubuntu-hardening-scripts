#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# harden.sh - Ubuntu/Debian Security Hardening Entry Point
#
# Usage:
#   sudo ./harden.sh              # Apply all hardening modules
#   sudo ./harden.sh --dry-run    # Preview changes without applying
#   sudo ./harden.sh --rollback   # Revert all changes
#   sudo ./harden.sh --modules ssh,firewall  # Run specific modules
#   sudo ./harden.sh --help       # Show usage information
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export SCRIPT_DIR

# Source shared libraries
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/rollback.sh"

# ---- Defaults ----
DRY_RUN="false"
DO_ROLLBACK="false"
SELECTED_MODULES=""
ROLLBACK_LOG="/var/log/hardening/rollback-$(date +%Y%m%d-%H%M%S).log"
BACKUP_DIR="/var/log/hardening/backups"
export DRY_RUN ROLLBACK_LOG BACKUP_DIR

# ---- Available modules (order matters) ----
ALL_MODULES="ssh firewall kernel users services filesystem logging updates"

# ==============================================================
# show_help - Display usage information
# ==============================================================
show_help() {
    cat <<'HELP'
Ubuntu Hardening Scripts
========================

Usage: sudo ./harden.sh [OPTIONS]

Options:
  --dry-run          Preview changes without applying them
  --rollback         Revert all changes from the most recent run
  --modules LIST     Comma-separated list of modules to run
                     Available: ssh, firewall, kernel, users, services,
                                filesystem, logging, updates
  --help             Show this help message

Examples:
  sudo ./harden.sh                          # Apply all modules
  sudo ./harden.sh --dry-run                # Preview all changes
  sudo ./harden.sh --modules ssh,firewall   # Harden SSH and firewall only
  sudo ./harden.sh --rollback               # Undo all changes

Configuration:
  Edit config.yml to customize settings before running.

HELP
}

# ==============================================================
# parse_args - Parse command line arguments
# ==============================================================
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run)
                DRY_RUN="true"
                export DRY_RUN
                shift
                ;;
            --rollback)
                DO_ROLLBACK="true"
                shift
                ;;
            --modules)
                if [[ -z "${2:-}" ]]; then
                    print_error "--modules requires a comma-separated list"
                    exit 1
                fi
                SELECTED_MODULES="$2"
                shift 2
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# ==============================================================
# init - Initialize logging directory and rollback log
# ==============================================================
init() {
    mkdir -p /var/log/hardening/backups
    touch "${ROLLBACK_LOG}"

    echo ""
    echo -e "${BLUE}╔══════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║     Ubuntu Hardening Scripts v1.0        ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════╝${NC}"
    echo ""

    if [[ "${DRY_RUN}" == "true" ]]; then
        print_warning "DRY-RUN MODE: No changes will be applied"
        echo ""
    fi

    print_info "Rollback log: ${ROLLBACK_LOG}"
    print_info "Backup dir:   ${BACKUP_DIR}"
    print_info "Config file:  ${CONFIG_FILE}"
    echo ""
}

# ==============================================================
# run_module - Source and execute a single hardening module
# ==============================================================
run_module() {
    local module="$1"
    local module_file="${SCRIPT_DIR}/modules/${module}.sh"

    if [[ ! -f "${module_file}" ]]; then
        print_error "Module not found: ${module_file}"
        return 1
    fi

    source "${module_file}"

    case "${module}" in
        ssh)        harden_ssh ;;
        firewall)   harden_firewall ;;
        kernel)     harden_kernel ;;
        users)      harden_users ;;
        services)   harden_services ;;
        filesystem) harden_filesystem ;;
        logging)    harden_logging ;;
        updates)    harden_updates ;;
        *)
            print_error "Unknown module: ${module}"
            return 1
            ;;
    esac
}

# ==============================================================
# show_summary - Display summary of changes made
# ==============================================================
show_summary() {
    print_section "Hardening Summary"

    if [[ "${DRY_RUN}" == "true" ]]; then
        print_warning "DRY-RUN: No changes were made"
        return
    fi

    if [[ -f "${ROLLBACK_LOG}" ]]; then
        local change_count
        change_count=$(wc -l < "${ROLLBACK_LOG}")
        print_ok "Total changes applied: ${change_count}"
        print_info "Rollback log saved to: ${ROLLBACK_LOG}"
        print_info "To undo all changes, run: sudo $0 --rollback"
    else
        print_info "No changes were recorded"
    fi

    echo ""
    print_warning "IMPORTANT: If you changed the SSH port, make sure you can"
    print_warning "still connect before closing this session!"
    echo ""
}

# ==============================================================
# main - Entry point
# ==============================================================
main() {
    parse_args "$@"

    # Check for root
    check_root

    # Handle rollback
    if [[ "${DO_ROLLBACK}" == "true" ]]; then
        perform_rollback
        exit 0
    fi

    # Initialize
    init

    # Determine which modules to run
    local modules_to_run
    if [[ -n "${SELECTED_MODULES}" ]]; then
        modules_to_run=$(echo "${SELECTED_MODULES}" | tr ',' ' ')
    else
        # Read enabled modules from config
        local config_modules
        config_modules=$(parse_config "enable_modules")
        if [[ -n "${config_modules}" ]]; then
            modules_to_run="${config_modules}"
        else
            modules_to_run="${ALL_MODULES}"
        fi
    fi

    print_info "Modules to run: ${modules_to_run}"
    echo ""

    # Run each module
    local failed_modules=()
    for module in ${modules_to_run}; do
        if run_module "${module}"; then
            :
        else
            failed_modules+=("${module}")
            print_error "Module '${module}' failed"
        fi
    done

    # Show summary
    show_summary

    # Report failures
    if [[ ${#failed_modules[@]} -gt 0 ]]; then
        print_error "The following modules had errors: ${failed_modules[*]}"
        exit 1
    fi
}

main "$@"
