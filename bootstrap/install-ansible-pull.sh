#!/bin/bash
# install-ansible-pull.sh
# Installs ansible-pull and a systemd timer that keeps this laptop in line with Git.
# Run once per laptop: by hand in the lab, as a Fleet script, or from autoinstall late-commands.
#
# Usage: sudo ./install-ansible-pull.sh <repo-url> [branch]
#   e.g. sudo ./install-ansible-pull.sh https://github.com/<you>/laptop-config.git main
#
# Behaviour of each run (every 30 min, and 5 min after boot):
#   - normally: only runs the playbook if Git has new commits (--only-if-changed)
#   - once every 24h: runs the full playbook anyway, so local drift gets repaired
#   - always: stamps /etc/zt/ansible-last-check so Fleet can tell the timer is alive
set -euo pipefail

# Fleet scripts cannot take arguments: set your repo here before uploading to Fleet.
DEFAULT_REPO="https://github.com/kere-sifon/laptop-config.git"
DEFAULT_BRANCH="main"

REPO="${1:-$DEFAULT_REPO}"; BRANCH="${2:-$DEFAULT_BRANCH}"
case "$REPO" in *CHANGE-ME*) echo "Set DEFAULT_REPO in this script (or pass the URL as an argument)"; exit 1;; esac
[ "$(id -u)" -eq 0 ] || { echo "run with sudo"; exit 1; }
export DEBIAN_FRONTEND=noninteractive

# Skip apt when already installed: a fresh laptop is often busy with unattended-upgrades,
# and waiting on the apt lock can push this past Fleet's script timeout.
if ! command -v ansible-pull >/dev/null 2>&1 || ! command -v git >/dev/null 2>&1; then
  apt-get -o DPkg::Lock::Timeout=120 update -qq
  apt-get -o DPkg::Lock::Timeout=120 install -y -qq ansible-core git
fi
echo "ansible-core present: $(ansible --version | head -1)"

install -d -m 0755 /etc/zt /var/lib/zt
cat > /etc/zt/ansible-pull.env <<EOF
ZT_REPO=$REPO
ZT_BRANCH=$BRANCH
EOF

cat > /usr/local/sbin/zt-ansible-pull <<'EOF'
#!/bin/bash
set -uo pipefail
. /etc/zt/ansible-pull.env
DIR=/var/lib/zt/ansible
FULL_STAMP=/var/lib/zt/ansible-last-full
mode=(--only-if-changed)
if [ ! -f "$FULL_STAMP" ] || [ -n "$(find "$FULL_STAMP" -mmin +1440)" ]; then
  mode=()   # daily full run for drift repair
fi
ansible-pull -U "$ZT_REPO" -C "$ZT_BRANCH" -d "$DIR" -i localhost, "${mode[@]}" local.yml
rc=$?
date -Is > /etc/zt/ansible-last-check
[ "$rc" -eq 0 ] && touch /etc/zt/ansible-last-ok      # Fleet checks this file's age
[ "$rc" -eq 0 ] && [ "${#mode[@]}" -eq 0 ] && touch "$FULL_STAMP"
echo "rc=$rc" >> /etc/zt/ansible-last-check
exit "$rc"
EOF
chmod 0755 /usr/local/sbin/zt-ansible-pull

cat > /etc/systemd/system/zt-ansible-pull.service <<'EOF'
[Unit]
Description=Apply Celestica laptop config from Git (ansible-pull)
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/zt-ansible-pull
Nice=10
IOSchedulingClass=idle
EOF

cat > /etc/systemd/system/zt-ansible-pull.timer <<'EOF'
[Unit]
Description=Run ansible-pull every 30 minutes

[Timer]
OnBootSec=5min
OnUnitActiveSec=30min
RandomizedDelaySec=5min
Persistent=true

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable --now zt-ansible-pull.timer
# Start the first pull in the background so this script returns quickly
# (Fleet scripts time out; the first pull can take a few minutes).
systemctl start --no-block zt-ansible-pull.service
echo "OK: ansible-pull installed for $REPO ($BRANCH); first pull started in the background."
echo "Check later: cat /etc/zt/ansible-state.json /etc/zt/ansible-last-check"
