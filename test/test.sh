#!/usr/bin/env bash

CURRENT_DIR="$(dirname "${BASH_SOURCE[0]}")"

mv "${CURRENT_DIR}/dist" "${CURRENT_DIR}/dist-old"

"${CURRENT_DIR}/update-dist.sh"

diff "${CURRENT_DIR}/dist-old"  "${CURRENT_DIR}/dist" || exit 1

rm -rf "${CURRENT_DIR}/dist-old"

SRC_OUTPUT="$(bash "${CURRENT_DIR}/src/main.sh")"
DIST_OUTPUT="$(bash "${CURRENT_DIR}/dist/main.sh")"

diff <(echo "${SRC_OUTPUT}") <(echo "${DIST_OUTPUT}") || exit 1
