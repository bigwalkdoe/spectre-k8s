# spectre-k8s

`spectre-k8s` is an opinionated, config-driven bootstrap for fresh **Ubuntu** and **Debian** servers. It applies a secure host baseline and installs **k3s** (single-node server by default) so you can run Kubernetes workloads on a prepared machine.

- **Config-driven:** edit one file, run one command.
- **Idempotent:** safe to re-run; modules converge state.
- **Auditable:** modular Bash scripts, minimal prerequisites.
- **Baseline + Kubernetes:** host hardening plus k3s installation and kubeconfig setup.

## Supported systems

- Ubuntu and Debian (currently supported LTS/stable releases, e.g. Ubuntu 22.04/24.04+, Debian 12+)
- `systemd`-based systems with `apt`
- Root (or sudo) access and outbound network access for package installation

## Quick start

```bash
git clone git@github.com:bigwalkdoe/spectre-k8s.git
cd spectre-k8s

cp config/spectre-k8s.conf.example config/spectre-k8s.conf
# edit config/spectre-k8s.conf (set ADMIN_SSH_PUBLIC_KEYS, review firewall/k3s options)

# optional: validate config and preview planned modules without making changes
./setup.sh --dry-run   # or: ./setup.sh --check

sudo ./setup.sh
```

After completion, verify SSH access in a separate session. Then verify the cluster:

```bash
sudo k3s kubectl get nodes
```

If `K3S_SETUP_KUBECONFIG=yes` (default), the admin user's kubeconfig is installed at `~/.kube/config`.

## Configuration

Real configuration lives in `config/spectre-k8s.conf` (gitignored). Copy from `config/spectre-k8s.conf.example`.

| Key | Default | Description |
| --- | --- | --- |
| `ADMIN_USER` | `deploy` | Non-root admin user to create/ensure (added to `sudo`) |
| `ADMIN_SSH_PUBLIC_KEYS` | *(empty)* | Path to a file of public key(s), or inline public key material |
| `SSH_PORT` | `22` | SSH port |
| `SSH_PASSWORD_AUTH` | `no` | Allow password auth (`yes`/`no`) |
| `SSH_PERMIT_ROOT_LOGIN` | `no` | `PermitRootLogin` value |
| `SSH_PUBKEY_AUTH` | `yes` | Enable public key auth |
| `ALLOW_LOCKOUT_RISK` | `no` | Override lockout safety (only if you intentionally accept risk) |
| `UFW_ALLOWED_TCP_PORTS` | `6443` | Extra inbound TCP ports to allow (SSH is always allowed/rate-limited) |
| `UFW_ALLOWED_UDP_PORTS` | *(empty)* | Extra inbound UDP ports to allow (e.g. `8472` for Flannel VXLAN in multi-node setups) |
| `K3S_CHANNEL` | *(empty)* | k3s install channel (installer default if empty) |
| `K3S_VERSION` | *(empty)* | Specific k3s version (overrides channel behavior per installer) |
| `K3S_SERVER_ARGS` | *(empty)* | Extra args for `k3s server` install |
| `K3S_SETUP_KUBECONFIG` | `yes` | Copy kubeconfig to `ADMIN_USER`'s `~/.kube/config` |
| `K3S_INSTALL_SCRIPT_URL` | `https://get.k3s.io` | k3s installer script URL (override for mirrors/custom sources) |
| `BACKUP_ENABLED` | `yes` | Enable scheduled backups |
| `BACKUP_TARGET_DIR` | `/var/backups/spectre-k8s` | Backup archive directory |
| `BACKUP_PATHS` | `/etc /etc/spectre-k8s /var/lib/rancher/k3s/server` | Paths to back up (explicit) |
| `BACKUP_RETENTION_COUNT` | `7` | Number of archives to retain |
| `BACKUP_SCHEDULE` | `daily` | `daily`, `hourly`, or 5-field cron expression |

## What the bootstrap does

1. **Preflight**: verifies root, supported Ubuntu/Debian, apt, systemd.
2. **Users**: ensures admin user, sudo membership, SSH keys/permissions.
3. **SSH hardening**: managed drop-in, lockout safety, `sshd -t` before reload.
4. **Fail2ban**: protects SSH.
5. **Firewall (UFW)**: default deny incoming / allow outgoing, rate-limited SSH, configured extra ports (default includes `6443` for Kubernetes API). Review and adjust ports for your CNI/ingress/NodePort needs.
6. **Updates & time**: unattended security upgrades and time sync.
7. **k3s**: installs/configures single-node k3s server, enables service, waits for readiness (best-effort), optionally installs kubeconfig for admin user.
8. **Backups**: installs `/usr/local/sbin/spectre-k8s-backup` and schedules archives with retention.

## Security and operations notes

- **Config validation:** run `./setup.sh --dry-run` (or `--check`) to validate configuration and preview planned modules without making system changes.
- **SSH lockout safety:** with password auth disabled (default), setup fails if no admin key is available unless `ALLOW_LOCKOUT_RISK=yes`.
- **Firewall/Kubernetes networking:** default allows SSH and `6443/tcp`. Depending on your workload (ingress controllers, LoadBalancer/NodePort exposure, CNI requirements, multi-node expansion), you must explicitly allow required ports and validate reachability. Common additions: `80,443/tcp` for ingress; `8472/udp` (and related ports) for multi-node Flannel/VXLAN setups.
- **k3s options:** use `K3S_SERVER_ARGS` to tailor the server install (e.g. `--disable traefik`, `--disable servicelb`, `--write-kubeconfig-mode 0640`).
- **Backups:** explicit paths only (host/config and k3s server state by default). They do **not** automatically cover all workload data/PVC contents; back up application data separately as needed.
- **Idempotency:** re-running `sudo ./setup.sh` is supported.

## Backups and restore

- Manual backup: `sudo /usr/local/sbin/spectre-k8s-backup`
- List archives: `sudo /usr/local/sbin/spectre-k8s-backup --list`
- Logs: `/var/log/spectre-k8s-backup.log`
- Restore carefully by extracting required files/config/state from archives and restarting affected services. For k3s state recovery, follow k3s backup/restore guidance appropriate to your datastore/topology and test restores in a safe environment.

## Development checks

```bash
find . -name "*.sh" -type f -print0 | xargs -0 -n1 bash -n
# if available:
shellcheck -S style setup.sh lib/*.sh modules/*.sh templates/backup/spectre-k8s-backup.sh
```

## License

MIT. See [LICENSE](LICENSE).
