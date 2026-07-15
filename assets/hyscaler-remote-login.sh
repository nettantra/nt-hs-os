#!/usr/bin/env bash
# Enable gnome-remote-desktop Remote Login on first boot.
#
# Runs once, on the installed machine, never in the image. The TLS key is
# generated here and only here: an ISO carrying a private key would give the
# same key to every machine ever installed from it, and anyone who downloads
# the ISO would hold it (ADR 0005).
#
# Remote Login hands an incoming RDP connection to a headless instance of the
# real GDM greeter. That is what lets authd render its device-code prompt, and
# it is the whole reason we run gnome-remote-desktop rather than xrdp.
set -euo pipefail

STATE=/var/lib/hyscaler/remote-login.done
CERT_DIR=/etc/hyscaler/remote-login
CERT="$CERT_DIR/rdp-tls.crt"
KEY="$CERT_DIR/rdp-tls.key"

[ -e "$STATE" ] && { echo "already configured"; exit 0; }

command -v grdctl >/dev/null || { echo "grdctl not found; is gnome-remote-desktop installed?" >&2; exit 1; }

install -d -m 0755 "$CERT_DIR"
install -d -m 0755 "$(dirname "$STATE")"

if [ ! -f "$KEY" ]; then
  echo "Generating a per-machine RDP TLS certificate."
  openssl req -x509 -newkey rsa:4096 -nodes \
    -keyout "$KEY" -out "$CERT" -days 3650 \
    -subj "/CN=$(hostname -f 2>/dev/null || hostname)/O=HyScaler" \
    -addext "subjectAltName=DNS:$(hostname -f 2>/dev/null || hostname)"
  # The system daemon runs as the gnome-remote-desktop user, which must read
  # the key. 0640 root:gnome-remote-desktop, not 0644.
  chmod 0600 "$KEY"; chmod 0644 "$CERT"
  if getent passwd gnome-remote-desktop >/dev/null; then
    chown root:gnome-remote-desktop "$KEY" && chmod 0640 "$KEY"
  fi
fi

# --system targets the login screen, not a user session. This is Remote Login.
grdctl --system rdp set-tls-cert "$CERT"
grdctl --system rdp set-tls-key "$KEY"
grdctl --system rdp enable

systemctl enable --now gnome-remote-desktop.service

# Deliberately NOT opening 3389. Reaching this machine is expected to go via a
# VPN or bastion. "RDP is enabled" must never quietly mean "RDP is exposed."
echo "Remote Login enabled on 3389. The firewall was not modified."

touch "$STATE"
