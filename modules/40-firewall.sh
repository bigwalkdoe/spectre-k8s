#!/usr/bin/env bash
# shellcheck shell=bash

run_module() {
  log_info "Configuring UFW firewall for spectre-k8s..."
  ensure_packages ufw iproute2

  # Defaults
  ufw --force default deny incoming >/dev/null
  ufw --force default allow outgoing >/dev/null

  # Ensure SSH allowed (rate-limited) before enabling
  ufw limit "${SSH_PORT}/tcp" comment 'spectre-k8s SSH' >/dev/null 2>&1 || ufw limit "${SSH_PORT}/tcp" >/dev/null

  # Extra ports (e.g. Kubernetes API 6443, ingress 80/443)
  local p
  for p in ${UFW_ALLOWED_TCP_PORTS}; do
    [[ -z "$p" ]] && continue
    if [[ "$p" =~ ^[0-9]+$ ]]; then
      ufw allow "${p}/tcp" comment 'spectre-k8s extra' >/dev/null 2>&1 || ufw allow "${p}/tcp" >/dev/null
    else
      log_warn "Skipping invalid UFW_ALLOWED_TCP_PORTS entry: $p"
    fi
  done

  # Enable firewall (non-interactive)
  ufw --force enable >/dev/null
  log_ok "UFW enabled (default deny incoming, allow outgoing, SSH ${SSH_PORT}/tcp rate-limited)."
  log_info "Review Kubernetes networking/port requirements for your topology (API, CNI, ingress, NodePort ranges) and adjust UFW_ALLOWED_TCP_PORTS as needed."

  ufw status verbose || true
}
