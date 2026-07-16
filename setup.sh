#!/usr/bin/env bash
#
# HyScaler OS manual provisioner runner (passphrase model, ADR 0011).
#
# Published to the public repo beside payload.enc and payload.hmac. For running
# the provisioner by hand on an already-installed machine, when you do not want
# to wait for the first-boot service:
#
#   git clone https://github.com/nettantra/nt-hs-os
#   sudo ./nt-hs-os/setup.sh
#
# It prompts for the provisioning passphrase (the same one first boot asks for),
# verifies payload.enc against payload.hmac with it, decrypts, and runs it. This
# file carries no secret: without the passphrase, payload.enc is opaque, and any
# tampering is caught by the HMAC before a line runs.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENC="$HERE/payload.enc"
MAC="$HERE/payload.hmac"
ITER=200000

die() { printf '\033[31merror\033[0m %s\n' "$*" >&2; exit 1; }
say() { printf '\033[36m==>\033[0m %s\n' "$*"; }

[ "$(id -u)" -eq 0 ] || die "run as root: sudo $0"
command -v openssl >/dev/null || die "openssl not found"
[ -f "$ENC" ] || die "payload.enc not found next to this script"
[ -f "$MAC" ] || die "payload.hmac not found next to this script"

want="$(tr -d '[:space:]' < "$MAC")"

for attempt in 1 2 3; do
    # HS_TEST_PASSPHRASE lets automated checks skip the prompt.
    if [ -n "${HS_TEST_PASSPHRASE:-}" ]; then
        pass="$HS_TEST_PASSPHRASE"
    else
        read -r -s -p "HyScaler provisioning passphrase: " pass; echo
    fi
    [ -n "$pass" ] || { echo "empty passphrase"; continue; }

    got="$(openssl dgst -sha256 -hmac "$pass" "$ENC" | awk '{print $NF}')"
    if [ "$want" != "$got" ]; then
        echo "wrong passphrase (integrity check failed), attempt $attempt/3"
        [ -n "${HS_TEST_PASSPHRASE:-}" ] && die "passphrase rejected"
        continue
    fi

    say "Passphrase accepted; decrypting"
    tmp="$(mktemp)"; chmod 0700 "$tmp"; trap 'rm -f "$tmp"' EXIT
    openssl enc -d -aes-256-cbc -pbkdf2 -iter "$ITER" -pass "pass:$pass" \
        -in "$ENC" -out "$tmp" 2>/dev/null || die "decryption failed after integrity check passed"
    say "Running provisioner"
    bash "$tmp"
    say "Done"
    exit 0
done

die "no valid passphrase after 3 attempts"
