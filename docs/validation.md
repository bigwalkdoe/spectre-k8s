# spectre-k8s validation checklist

Use this checklist to validate `spectre-k8s` on fresh **Ubuntu** and **Debian** hosts (e.g. Ubuntu 22.04/24.04 LTS, Debian 12). Run on disposable or snapshot-backed instances where possible.

## Preparation
- [ ] Provision a fresh host and confirm OS: `cat /etc/os-release`
- [ ] Ensure outbound network access and sudo/root access
- [ ] Clone repo and create config:
  ```bash
  git clone git@github.com:bigwalkdoe/spectre-k8s.git
  cd spectre-k8s
  cp config/spectre-k8s.conf.example config/spectre-k8s.conf
  ```
- [ ] Set `ADMIN_SSH_PUBLIC_KEYS` and review SSH, firewall ports (e.g. `6443`, ingress), k3s, and backup settings

## First run
- [ ] Run: `sudo ./setup.sh` (optionally `./setup.sh --dry-run` first)
- [ ] Confirm exit code 0 and summary shows modules run
- [ ] **Do not close current session yet** — verify SSH access in a separate session as `ADMIN_USER` on `SSH_PORT`

## Baseline checks
- [ ] User/groups: `id <ADMIN_USER>` includes `sudo`
- [ ] SSH effective config: `sudo sshd -T | egrep 'port|permitrootlogin|passwordauthentication|pubkeyauthentication|maxauthtries'`
- [ ] SSH service active: `systemctl is-active ssh || systemctl is-active sshd`
- [ ] UFW: `sudo ufw status verbose` (default deny incoming, SSH limited, configured ports allowed)
- [ ] Fail2ban: `sudo fail2ban-client status sshd`
- [ ] Unattended upgrades/time sync: `systemctl is-active unattended-upgrades` and `timedatectl status`
- [ ] k3s: `sudo systemctl is-active k3s`, `sudo k3s --version`, `sudo k3s kubectl get nodes -o wide`
- [ ] Kubeconfig (if enabled): `sudo -u <ADMIN_USER> KUBECONFIG=~<ADMIN_USER>/.kube/config kubectl get nodes`

## Idempotency
- [ ] Re-run: `sudo ./setup.sh`
- [ ] Confirm no errors, minimal/no unnecessary restarts, no duplicate authorized keys, cron entries, or UFW rule growth
- [ ] Spot-check managed files: `/etc/ssh/sshd_config.d/99-spectre-k8s.conf`, `/etc/fail2ban/jail.d/spectre-k8s.local`, `/etc/cron.d/spectre-k8s-backup`

## Backups
- [ ] Manual run: `sudo /usr/local/sbin/spectre-k8s-backup`
- [ ] Archive created: `sudo /usr/local/sbin/spectre-k8s-backup --list`
- [ ] Inspect contents: `sudo tar -tzf <archive> | head`
- [ ] Retention/prune behavior verified
- [ ] Restore drill (safe path): extract sample files to temp location and compare

## Firewall/Kubernetes exposure
- [ ] From another host, confirm only intended ports are reachable (SSH, `6443` if intended, ingress/NodePorts if configured)
- [ ] Validate workload exposure matches expectations for your CNI/ingress configuration

## Negative/safety checks (controlled)
- [ ] Invalid config syntax/value rejected clearly
- [ ] Lockout safety blocks risky SSH config without keys/override
- [ ] Unsupported OS fails clearly

## Record results
- OS/version, kernel, k3s version, firewall backend, deviations, and logs/output for failures.
