#!/usr/bin/env bash
# setup-oci-server.sh — One-time server provisioning for OpenClaw on OCI Ubuntu
#
# Run on the OCI server as root (or with sudo):
#   curl -fsSL https://raw.githubusercontent.com/ReaperOAK/openclaw/main/scripts/setup-oci-server.sh | sudo bash
#
# Or upload and run:
#   scp scripts/setup-oci-server.sh ubuntu@80.225.219.45:/tmp/
#   ssh ubuntu@80.225.219.45 'sudo bash /tmp/setup-oci-server.sh'
set -euo pipefail

log() { echo "[SETUP $(date -u +%H:%M:%S)] $*"; }

log "Starting OCI server provisioning for OpenClaw"

# ── System updates ──
log "Updating system packages"
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq

# ── Essential packages ──
log "Installing essential packages"
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
  curl wget git jq htop tree unzip \
  ufw fail2ban \
  nginx certbot python3-certbot-nginx \
  logrotate

# ── Docker ──
if ! command -v docker &>/dev/null; then
  log "Installing Docker"
  curl -fsSL https://get.docker.com | sh
  usermod -aG docker ubuntu
else
  log "Docker already installed: $(docker --version)"
fi

# ── Directory structure ──
log "Creating OpenClaw directory structure"
mkdir -p /opt/openclaw/{releases,shared/{openclaw-data,workspace},backups/pre-deploy,logs,scripts}
chown -R ubuntu:ubuntu /opt/openclaw

# ── Firewall (UFW) ──
log "Configuring UFW firewall"
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw limit 22/tcp comment 'SSH rate-limited'
ufw allow 80/tcp comment 'HTTP'
ufw allow 443/tcp comment 'HTTPS'
ufw --force enable

# ── Fail2ban ──
log "Configuring Fail2ban"
cat > /etc/fail2ban/jail.local << 'JAIL'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3
backend = systemd
banaction = ufw

[sshd]
enabled = true
port = ssh
filter = sshd
maxretry = 3
bantime = 86400

[nginx-http-auth]
enabled = true
port = http,https
filter = nginx-http-auth
maxretry = 5

[nginx-limit-req]
enabled = true
port = http,https
filter = nginx-limit-req
maxretry = 10
findtime = 120
bantime = 600
JAIL

systemctl enable fail2ban
systemctl restart fail2ban

# ── SSH hardening ──
log "Hardening SSH"
cat > /etc/ssh/sshd_config.d/openclaw-hardening.conf << 'SSHD'
PasswordAuthentication no
ChallengeResponseAuthentication no
PermitRootLogin no
AllowUsers ubuntu
PubkeyAuthentication yes
MaxAuthTries 3
MaxSessions 5
LoginGraceTime 30
X11Forwarding no
AllowTcpForwarding no
PermitTunnel no
LogLevel VERBOSE
SSHD

# Validate sshd config before restarting
if sshd -t; then
  systemctl restart sshd
  log "SSH hardening applied"
else
  rm -f /etc/ssh/sshd_config.d/openclaw-hardening.conf
  log "WARNING: SSH config invalid — reverted"
fi

# ── systemd service ──
log "Creating systemd service"
cat > /etc/systemd/system/openclaw.service << 'SYSTEMD'
[Unit]
Description=OpenClaw AI Gateway (Docker Compose)
After=docker.service network-online.target
Requires=docker.service
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
User=ubuntu
Group=ubuntu
WorkingDirectory=/opt/openclaw/current
ExecStart=/usr/bin/docker compose -f docker-compose.production.yml -p openclaw up -d --remove-orphans
ExecStop=/usr/bin/docker compose -f docker-compose.production.yml -p openclaw down
ExecReload=/usr/bin/docker compose -f docker-compose.production.yml -p openclaw restart
TimeoutStartSec=120
TimeoutStopSec=60

[Install]
WantedBy=multi-user.target
SYSTEMD

systemctl daemon-reload
systemctl enable openclaw.service

# ── Logrotate ──
log "Configuring log rotation"
cat > /etc/logrotate.d/openclaw << 'LOGROTATE'
/opt/openclaw/logs/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 0644 ubuntu ubuntu
}
LOGROTATE

# ── Automatic security updates ──
log "Enabling automatic security updates"
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq unattended-upgrades
dpkg-reconfigure -plow unattended-upgrades

# ── Cron jobs ──
log "Setting up cron jobs for ubuntu user"
# Backup: daily at 3 AM UTC
(sudo -u ubuntu crontab -l 2>/dev/null || true; echo "0 3 * * * /opt/openclaw/scripts/backup.sh >> /opt/openclaw/logs/backup.log 2>&1") | sudo -u ubuntu crontab -

# Docker cleanup: weekly
(sudo -u ubuntu crontab -l 2>/dev/null || true; echo "0 4 * * 0 docker system prune -f --filter 'until=168h' >> /opt/openclaw/logs/docker-cleanup.log 2>&1") | sudo -u ubuntu crontab -

# ── Summary ──
log ""
log "════════════════════════════════════════════"
log "  OCI Server Provisioning Complete"
log "════════════════════════════════════════════"
log ""
log "  Next steps:"
log "  1. Create /opt/openclaw/shared/.env with your secrets"
log "  2. Create /opt/openclaw/shared/docker-compose.production.yml"
log "  3. Set up nginx: /etc/nginx/sites-available/openclaw"
log "  4. Get SSL: sudo certbot --nginx -d your-domain.com"
log "  5. Push to main branch to trigger deployment"
log ""
log "  Verify:"
log "    sudo ufw status verbose"
log "    sudo fail2ban-client status sshd"
log "    sudo systemctl status docker"
log "    ls -la /opt/openclaw/"
log ""
