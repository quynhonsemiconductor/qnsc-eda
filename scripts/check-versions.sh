#!/usr/bin/env bash
# =============================================================================
# Build-time gate: the five tools the platform's toolchain policy pins must be EXACTLY these versions.
#
# The OSS CAD Suite is built from upstream master/main, so the dated build
# carries development versions of Verilator, Yosys and cocotb.  This image
# installs the released versions on top and this script proves the overlays took
# effect (a PATH mistake would silently run the suite's copy).
#
# Run during `docker build` (the last step of the runtime stage) and again by
# the image workflow against the published digest.
# =============================================================================
set -euo pipefail

EXPECT_VERILATOR="5.054"
EXPECT_YOSYS="0.70"
EXPECT_COCOTB="2.1.0"
EXPECT_VERIBLE="v0.0-4298-g085eef05"
EXPECT_SURFER="0.7.0"

fail=0
ok()   { printf 'ok   %-10s %s\n' "$1" "$2"; }
bad()  { printf 'FAIL %-10s expected %s, got: %s\n' "$1" "$2" "$3" >&2; fail=1; }

# --- Verilator ---------------------------------------------------------------
v="$(verilator --version | awk 'NR==1 {print $2}')"
[ "$v" = "$EXPECT_VERILATOR" ] && ok verilator "$v" || bad verilator "$EXPECT_VERILATOR" "$v"

# --- Yosys -------------------------------------------------------------------
v="$(yosys -V | awk 'NR==1 {print $2}')"
[ "$v" = "$EXPECT_YOSYS" ] && ok yosys "$v" || bad yosys "$EXPECT_YOSYS" "$v"

# --- cocotb ------------------------------------------------------------------
v="$(/opt/cocotb/bin/python -c 'import cocotb; print(cocotb.__version__)')"
[ "$v" = "$EXPECT_COCOTB" ] && ok cocotb "$v" || bad cocotb "$EXPECT_COCOTB" "$v"
v="$(cocotb-config --version)"
[ "$v" = "$EXPECT_COCOTB" ] && ok cocotb-config "$v" || bad cocotb-config "$EXPECT_COCOTB" "$v"

# --- Verible -----------------------------------------------------------------
# The release binary prints "Version\tv0.0-4298-g085eef05" on its first line
# (verified against the v0.0-4298-g085eef05 static release); the second line is
# Commit-Timestamp.
v="$(verible-verilog-lint --version | awk '$1 == "Version" {print $2; exit}')"

[ "$v" = "$EXPECT_VERIBLE" ] && ok verible "$v" || bad verible "$EXPECT_VERIBLE" "$v"

# --- Surfer (and its remote server) -----------------------------------------
v="$(surfer --version | awk '{print $2}')"
[ "$v" = "$EXPECT_SURFER" ] && ok surfer "$v" || bad surfer "$EXPECT_SURFER" "$v"
v="$(surver --version | awk '{print $2}')"
[ "$v" = "$EXPECT_SURFER" ] && ok surver "$v" || bad surver "$EXPECT_SURFER" "$v"

# --- The overlay must actually win over the suite's copy ---------------------
for tool in verilator yosys surfer surver cocotb-config; do
  p="$(command -v "$tool")"
  case "$p" in
    /usr/local/bin/*) ;;
    *) printf 'FAIL %-10s resolves to %s, not the pinned /usr/local/bin copy\n' "$tool" "$p" >&2; fail=1 ;;
  esac
done

[ "$fail" -eq 0 ] || { echo "version gate failed" >&2; exit 1; }
echo "all five toolchain pins match"
