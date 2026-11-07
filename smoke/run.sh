#!/usr/bin/env bash
# Smoke regression: verilate and simulate the tiny core with the image's pinned
# Verilator.  Used by the Renovate bump PR build, the main build and the
# published-digest check.
set -euo pipefail

cd /opt/smoke
rm -rf /tmp/qnsc-eda-smoke
verilator --binary --timing -j 4 --top-module tb_tiny -Wno-fatal \
  -Mdir /tmp/qnsc-eda-smoke tiny_core.sv tb_tiny.sv
out="$(/tmp/qnsc-eda-smoke/Vtb_tiny)"
printf '%s\n' "$out"
grep -q '^SMOKE PASS' <<<"$out"

# The two browser apps the Coder workspace template starts.
code-server --version | head -1

test -f /opt/surfer-web/index.html || { echo "FAIL surfer-web: /opt/surfer-web/index.html missing" >&2; exit 1; }
compgen -G '/opt/surfer-web/*.wasm' >/dev/null || { echo "FAIL surfer-web: no wasm bundle in /opt/surfer-web" >&2; exit 1; }
echo "browser apps: $(code-server --version | head -1), surfer-web bundle present"
