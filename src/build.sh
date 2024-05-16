#!/usr/bin/env bash

CURRENT_DIR="$(dirname "${BASH_SOURCE[0]}")"

"${CURRENT_DIR}/embed.sh" "${CURRENT_DIR}/embed.sh" > "${CURRENT_DIR}/../embed.sh"
chmod +x "${CURRENT_DIR}/../embed.sh"
