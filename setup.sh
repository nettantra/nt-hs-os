#!/usr/bin/env bash
#
# HyScaler OS encrypted payload loader.
#
# Published, with payload.enc and payload.hmac beside it, to
#   git@github.com:nettantra/nt-hs-os.git
#
# On a HyScaler OS machine:
#
#   git clone git@github.com:nettantra/nt-hs-os.git
#   sudo ./nt-hs-os/setup.sh
#
# It reads the decryption secret from the local machine. That secret ships only
# on the HyScaler OS ISO, so this repository can be shared, even publicly,
# without exposing the payload: without the secret, payload.enc is opaque, and
# any edit to it is caught by the HMAC before a single line runs.
#
# This file itself carries no secret. Its integrity relies on access control of
# the git repository, the same as any bootstrap script.
set -euo pipefail

SECRET_FILE="${HS_PAYLOAD_SECRET_FILE:-/etc/hyscaler/payload.secret}"
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

if [ ! -r "$SECRET_FILE" ]; then
    die "no payload secret at $SECRET_FILE.
     This machine was not installed from the HyScaler OS ISO, or the secret was
     removed. The payload can only be decrypted on a HyScaler OS machine."
fi
secret="$(cat "$SECRET_FILE")"
[ -n "$secret" ] || die "$SECRET_FILE is empty"

# Integrity first, then decrypt. Verifying the HMAC over the ciphertext before
# decrypting means a tampered payload.enc is rejected without ever being turned
# into code, let alone run. Forging a valid HMAC requires the secret, which an
# attacker with only the repo does not have.
say "Verifying payload"
want="$(tr -d '[:space:]' < "$MAC")"
got="$(openssl dgst -sha256 -hmac "$secret" "$ENC" | awk '{print $NF}')"
if [ "$want" != "$got" ]; then
    die "payload failed its integrity check.
     Either this machine's secret does not match the one the payload was
     encrypted with, or payload.enc has been altered. Refusing to run it."
fi
say "Integrity OK"

# Decrypt into a private file, run it, and shred it. Never leave the plaintext
# on disk, and never pipe it through a world-readable path.
tmp="$(mktemp)"
chmod 0700 "$tmp"
cleanup() { rm -f "$tmp"; }
trap cleanup EXIT

if ! openssl enc -d -aes-256-cbc -pbkdf2 -iter "$ITER" \
        -pass "pass:$secret" -in "$ENC" -out "$tmp" 2>/dev/null; then
    die "decryption failed after the integrity check passed. This should not
     happen; the payload may have been produced with different openssl options."
fi

say "Running payload"
bash "$tmp"
say "Done"
