#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "${SCRIPT_DIR}/lib/common.sh"

VERSION="0.1.0"
CONFIG_PATH="${SCRIPT_DIR}/config/spectre-k8s.conf"
DRY_RUN=0

usage() {
  cat <<'EOF'
spectre-k8s - Ubuntu/Debian Kubernetes (k3s) host bootstrap

Usage:
  sudo ./setup.sh [--config PATH] [--dry-run] [--help] [--version]

Options:
  --config PATH   Path to config file (default: ./config/spectre-k8s.conf)
  --dry-run       Validate config and show planned actions without making changes
  --help          Show this help and exit
  --version       Show version and exit

Steps:
  1. Copy config/spectre-k8s.conf.example to config/spectre-k8s.conf
  2. Edit config/spectre-k8s.conf
  3. Run: sudo ./setup.sh
EOF
}

log_header() {
  printf '\n%s==>%s %s\n' "${_c_green}" "${_c_reset}" "$*"
}

main() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help|-h)
        usage
        exit 0
        ;;
      --version)
        echo "spectre-k8s ${VERSION}"
        exit 0
        ;;
      --dry-run)
        DRY_RUN=1
        ;;
      --config)
        shift
        [[ $# -gt 0 ]] || die "--config requires a path"
        CONFIG_PATH="$1"
        ;;
      --config=*)
        CONFIG_PATH="${1#*=}"
        ;;
      *)
        die "Unknown argument: $1 (use --help)"
        ;;
    esac
    shift
  done

  log_header "spectre-k8s setup"
  log_info "Config: ${CONFIG_PATH}"

  load_config "$CONFIG_PATH"
  apply_config_defaults
  validate_config
  check_lockout_safety

  local modules_dir="${SCRIPT_DIR}/modules"
  local -a modules=()
  if [[ -d "$modules_dir" ]]; then
    while IFS= read -r mod; do
      [[ -z "$mod" ]] && continue
      modules+=("$mod")
    done < <(find "$modules_dir" -maxdepth 1 -type f -name '[0-9][0-9]-*.sh' | sort)
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    log_header "Dry run (no changes will be made)"
    detect_os || true
    log_info "Detected OS: ${SPECTRE_OS_ID:-unknown} ${SPECTRE_OS_VERSION_ID:-} (${SPECTRE_OS_CODENAME:-unknown})"
    log_info "Admin user: ${ADMIN_USER}"
    log_info "SSH: port=${SSH_PORT}, password_auth=${SSH_PASSWORD_AUTH}, permit_root_login=${SSH_PERMIT_ROOT_LOGIN}, pubkey_auth=${SSH_PUBKEY_AUTH}"
    log_info "Firewall: extra TCP ports='${UFW_ALLOWED_TCP_PORTS:-none}', extra UDP ports='${UFW_ALLOWED_UDP_PORTS:-none}'"
    log_info "k3s: channel='${K3S_CHANNEL:-default}', version='${K3S_VERSION:-default}', setup_kubeconfig=${K3S_SETUP_KUBECONFIG}"
    log_info "Backups: enabled=${BACKUP_ENABLED}, target=${BACKUP_TARGET_DIR}, retention=${BACKUP_RETENTION_COUNT}, schedule=${BACKUP_SCHEDULE}"
    log_info "Planned modules (${#modules[@]}):"
    local m
    for m in "${modules[@]}"; do
      log_info "  - $(basename "$m")"
    done
    if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
      log_warn "Dry run executed without root; system state was not inspected."
    fi
    log_ok "Dry run completed (configuration validated)."
    return 0
  fi

  # Most operations require root; enforce here before running modules.
  require_root
  assert_supported_os

  # Managed state directory for spectre-k8s (config copy, markers)
  mkdir -p /etc/spectre-k8s
  chmod 755 /etc/spectre-k8s
  if [[ -f "$CONFIG_PATH" ]]; then
    install -m 600 "$CONFIG_PATH" /etc/spectre-k8s/spectre-k8s.conf
  fi

  local ran=0
  local mod
  for mod in "${modules[@]}"; do
    log_header "Module: $(basename "$mod")"
    # shellcheck disable=SC1090
    . "$mod"
    if declare -F run_module >/dev/null 2>&1; then
      run_module
      unset -f run_module
      ran=$((ran+1))
    else
      log_warn "Module $(basename "$mod") defines no run_module; skipping"
    fi
  done

  log_header "Summary"
  log_ok "spectre-k8s setup completed (modules run: ${ran})."
  log_info "Admin user: ${ADMIN_USER}"
  if command_exists systemctl; then
    local ssh_svc
    ssh_svc="$(get_ssh_service_name 2>/dev/null || echo ssh)"
    if systemctl is-active --quiet "$ssh_svc" 2>/dev/null; then
      log_info "Check: SSH service (${ssh_svc}) is active."
    else
      log_warn "Check: SSH service (${ssh_svc}) not active."
    fi
    if systemctl is-active --quiet ufw 2>/dev/null; then
      log_info "Check: UFW is active."
    else
      log_warn "Check: UFW not active."
    fi
    if systemctl is-active --quiet k3s 2>/dev/null; then
      log_info "Check: k3s service is active."
    else
      log_warn "Check: k3s service not active."
    fi
  fi
  log_info "Verify SSH access in a separate session before closing your current one."
  log_info "Verify cluster: sudo k3s kubectl get nodes"
}

main "$@"
