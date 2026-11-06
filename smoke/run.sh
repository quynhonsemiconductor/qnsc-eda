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
