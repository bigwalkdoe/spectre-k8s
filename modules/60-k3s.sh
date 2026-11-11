#!/usr/bin/env bash
# shellcheck shell=bash

run_module() {
  log_info "Installing and configuring k3s (single-node server)..."
  ensure_packages curl ca-certificates

  local install_env=()
  [[ -n "${K3S_CHANNEL:-}" ]] && install_env+=("INSTALL_K3S_CHANNEL=${K3S_CHANNEL}")
  [[ -n "${K3S_VERSION:-}" ]] && install_env+=("INSTALL_K3S_VERSION=${K3S_VERSION}")
  # Always install as server on this bootstrap
  install_env+=("INSTALL_K3S_EXEC=server ${K3S_SERVER_ARGS:-}")

  if command_exists k3s; then
    log_info "k3s already installed: $(k3s --version 2>/dev/null | head -n1 || echo 'unknown version')"
  else
    log_info "Running k3s installer from ${K3S_INSTALL_SCRIPT_URL}..."
    # shellcheck disable=SC2086
    curl -sfL "${K3S_INSTALL_SCRIPT_URL}" | env "${install_env[@]}" sh -
  fi

  systemctl enable k3s >/dev/null 2>&1 || true
  systemctl start k3s >/dev/null 2>&1 || systemctl restart k3s >/dev/null 2>&1 || true

  # Wait briefly for node readiness
  local _
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    if k3s kubectl get --raw='/readyz' >/dev/null 2>&1; then
      break
    fi
    sleep 3
  done

  if k3s kubectl get --raw='/readyz' >/dev/null 2>&1; then
    log_ok "k3s API is ready."
  else
    log_warn "k3s installed but API readiness not confirmed yet; check: systemctl status k3s && k3s kubectl get nodes"
  fi

  # Kubeconfig for admin user
  if [[ "${K3S_SETUP_KUBECONFIG:-yes}" == "yes" ]] && id "$ADMIN_USER" >/dev/null 2>&1; then
    local home_dir kube_dir
    home_dir="$(getent passwd "$ADMIN_USER" | cut -d: -f6)"
    if [[ -n "$home_dir" && -d "$home_dir" ]]; then
      kube_dir="$home_dir/.kube"
      mkdir -p "$kube_dir"
      if [[ -f /etc/rancher/k3s/k3s.yaml ]]; then
        install -m 0600 -o "$ADMIN_USER" -g "$ADMIN_USER" /etc/rancher/k3s/k3s.yaml "$kube_dir/config"
        log_ok "Installed kubeconfig for ${ADMIN_USER} at ${kube_dir}/config"
      else
        log_warn "k3s kubeconfig not found at /etc/rancher/k3s/k3s.yaml"
      fi
    fi
  fi

  log_ok "k3s module completed. Use 'k3s kubectl get nodes' (or kubectl with configured kubeconfig) to verify."
}
