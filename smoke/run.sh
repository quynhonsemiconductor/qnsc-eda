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
test -f /opt/surfer-web/VERSION || { echo "FAIL surfer-web: VERSION missing" >&2; exit 1; }
web_version="$(tr -d '[:space:]' < /opt/surfer-web/VERSION)"
native_version="$(surfer --version | awk '{print $2}')"
[ "${web_version#v}" = "$native_version" ] || {
  echo "FAIL surfer-web: bundle ${web_version}, native surfer ${native_version}" >&2; exit 1; }
echo "browser apps: $(code-server --version | head -1), surfer-web ${web_version}"
