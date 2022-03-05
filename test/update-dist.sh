#!/usr/bin/env bash

CURRENT_DIR="$(dirname "${BASH_SOURCE[0]}")"

mkdir -p "${CURRENT_DIR}/dist"

"${CURRENT_DIR}/../embed.sh" "${CURRENT_DIR}/src/main.sh" >"${CURRENT_DIR}/dist/main.sh"

"${CURRENT_DIR}/../embed.sh" --once=t "${CURRENT_DIR}/src/main.sh" >"${CURRENT_DIR}/dist/main-with-once.sh"
