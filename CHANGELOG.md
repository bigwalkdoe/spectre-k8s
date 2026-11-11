# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added
- Initial `spectre-k8s` bootstrap: config-driven, modular, idempotent setup for Ubuntu/Debian with secure host baseline and single-node k3s installation.
- Baseline hardening modules (preflight, users, SSH with lockout safety, fail2ban, UFW, unattended upgrades/time sync) and scheduled backups with retention.
- k3s installation/configuration module with optional kubeconfig setup for admin user and readiness checks.
- Documentation (`README.md`, `docs/validation.md`, `docs/spectre-k8s-plan.md`) and CI shell checks.
