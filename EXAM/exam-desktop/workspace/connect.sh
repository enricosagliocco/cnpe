#!/bin/bash

set -euo pipefail

KEY_SRC="id_rsa"
KEY_TMP="$(mktemp)"

cleanup() {
	rm -f "$KEY_TMP"
}
trap cleanup EXIT

cp "$KEY_SRC" "$KEY_TMP"
chmod 600 "$KEY_TMP"

ssh -o ServerAliveInterval=60 -o ServerAliveCountMax=3 opc@158.180.234.164 -i "$KEY_TMP"
