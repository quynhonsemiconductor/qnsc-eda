# qnsc-eda

The VLSI platform's open-source EDA toolchain, as one digest-pinned container
image. Design: `product-docs/projects/vlsi-platform/00_DESIGN.md` §4 and §6.

- **Base:** a pinned, dated [OSS CAD Suite](https://github.com/YosysHQ/oss-cad-suite-build)
  build (Icarus, SymbiYosys, GHDL, GTKWave and the rest of the suite).
- **Pinned on top:** Verilator, Yosys, cocotb, Verible and Surfer at the exact
  versions design §4 names. The suite tracks upstream `master`/`main`, so its
  dated build carries development versions of the first three; the Dockerfile
  builds/installs the releases over them and `scripts/check-versions.sh` fails
  the build unless all five are exact.
- **Non-root** (uid/gid 1001), **no PDK and no NDA data**. Never add foundry
  libraries, `.lib`/`.lef`/`.gds`, or memory-compiler output to this image.
- **Same digest** for the Coder workspace template and for the RTL CI
  `container:` jobs, so "passes in my workspace" equals "passes in CI".

## Pins

| Tool | Pin | Source |
|---|---|---|
| OSS CAD Suite | dated build `2026-11-05` | the newest stable release when this image was created (2026-11-06; that day's build had not been published yet) |
| Verilator | `5.054` | built from the `v5.054` tag (the suite carries 5.055-devel) |
| Yosys | `v0.70` | built from the `v0.70` tag (the suite carries 0.70+336) |
| cocotb | `2.1.0` | pip, in `/opt/cocotb` (the suite carries 2.1.0.dev0) |
| Verible | `v0.0-4298-g085eef05` | release, static linux-x64 |
| Surfer | `v0.7.0` | release; includes `surver` |

Surfer is the client; `surver` is its remote server (marked experimental
upstream — keep the local Surfer client as the fallback).

## Build

```sh
docker build --target eda -t qnsc-eda:local .
docker run --rm qnsc-eda:local check-versions
docker run --rm qnsc-eda:local bash /opt/smoke/run.sh
```

`--target eda` is the final stage. The version gate also runs inside the build,
so an image that builds is an image whose five pins match.

## Publish

Push to `main` runs `.github/workflows/image.yml`, which calls the org's
[`ci` GHCR reusable](https://github.com/quynhonsemiconductor/ci). That workflow
builds **once**, scans the image for CRITICAL CVEs and secrets **before** the
push, pushes the scanned layers to
`ghcr.io/quynhonsemiconductor/qnsc-eda:sha-<commit>`, and attaches provenance
and SBOM attestations to the pushed digest. The smoke job then pulls that
digest, re-runs the version gate and the regression, and verifies both
attestations.

The digest to pin in the Coder template and in a repo's CI is the `@sha256:…`
reported by the **Smoke (published digest)** job (and in the workflow summary).

```sh
docker pull ghcr.io/quynhonsemiconductor/qnsc-eda@sha256:<digest>
```

**Package visibility (owner, after the first publish).** GitHub does not inherit
the repository's visibility for a GHCR package. Either make the package public
(*Package settings → Change visibility → Public*) or grant
`quynhonsemiconductor/vlsi_deep_training` read under *Manage Actions access*;
otherwise another repo's `GITHUB_TOKEN` cannot pull it and the RTL CI
`container:` jobs fail at startup.

## Renovate

`renovate.json` adds a regex manager for `ARG OSS_CAD_SUITE_DATE` (suite tags
are dates, which the Dockerfile manager cannot read) and schedules the bump
monthly on the 1st. The PR is never automerged: the PR build re-runs the
version gate and the smoke regression (verilate + simulate `smoke/tiny_core.sv`)
so a suite bump is judged by a real build, not by the diff.

The Verilator/Yosys/cocotb/Verible/Surfer pins move only by editing the
Dockerfile arguments and the checksums in it; a bump is a deliberate change
because design §4 pins them.

## What is in the image

| What | Where |
|---|---|
| OSS CAD Suite | `/opt/oss-cad-suite` |
| Verilator 5.054 | `/opt/verilator`, `/usr/local/bin/verilator` |
| Yosys v0.70 | `/opt/yosys`, `/usr/local/bin/yosys` |
| cocotb 2.1.0 | `/opt/cocotb` (venv; `cocotb-config` on `PATH`) |
| Verible | `/opt/verible`, `/usr/local/bin/verible-*` |
| Surfer + surver | `/opt/surfer`, `/usr/local/bin/{surfer,surver}` |
| CI extras | `make`, `g++`, `git`, `emacs-nox`, `python3` + venv + PyYAML, `jq` |

`/usr/local/bin` precedes the suite's `bin`, so the five pinned tools win over
the suite's copies. `python3` is the distro interpreter (the repo's `make`
targets create venvs and import PyYAML); the suite's own scripts call their
bundled Python explicitly and are unaffected.
