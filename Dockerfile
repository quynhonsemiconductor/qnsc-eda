# syntax=docker/dockerfile:1.7
# =============================================================================
# qnsc-eda — the VLSI platform's open-source EDA toolchain image.
#
# The tool versions below are the ones the VLSI platform's toolchain policy pins.
#
#   * Base: the pinned, dated OSS CAD Suite build (YosysHQ/oss-cad-suite-build)
#     for the OSS tools it bundles (Icarus, SymbiYosys, GHDL, GTKWave, ...).
#   * The five tools the design pins EXACTLY are installed on top of the suite
#     and shadow its rolling copies:
#       Verilator 5.054, Yosys v0.70, cocotb 2.1.0, Verible
#       v0.0-4298-g085eef05, Surfer v0.7.0.
#     The suite builds those from upstream `master`/`main`, so a dated build
#     carries development versions (at 2026-11-05: Verilator 5.055-devel,
#     Yosys 0.70+336, cocotb 2.1.0.dev0).  The platform's toolchain policy requires the pinned
#     releases, so Verilator and Yosys are built from their release tags here
#     and cocotb/Surfer are installed from their releases.  scripts/
#     check-versions.sh fails the build if any of the five is not exact.
#   * No PDK, no NDA data: nothing in this build context or Dockerfile touches
#     foundry libraries.  Do not add one.
#   * Non-root: the image runs as uid 1001 (the GitHub-hosted runner user, so
#     `container:` jobs can write the mounted workspace; Coder mounts the PVC
#     at /home/eda).
#   * Multi-stage: downloads and source builds happen in throw-away stages; the
#     final stage carries only runtime packages, the tools and their data.
# =============================================================================
# ── Download the pinned upstream artefacts ──────────────────────────────────
FROM ubuntu:26.04@sha256:6a06111c3b0a8600feadb270aec771dc239bf407b25625f93f44ab00e11f4d3c AS fetch
ARG OSS_CAD_SUITE_DATE=2026-11-05
ARG VERIBLE_VERSION=v0.0-4298-g085eef05
ARG SURFER_VERSION=v0.7.0
# The suite is pinned by its dated release tag. GitHub publishes the tarball's
# SHA-256 with the release asset; the build refuses a different archive.
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl xz-utils unzip \
 && rm -rf /var/lib/apt/lists/*
RUN set -eux; \
    d="$(printf '%s' "${OSS_CAD_SUITE_DATE}" | tr -d -)"; \
    curl -fsSL -o /tmp/suite.tgz \
      "https://github.com/YosysHQ/oss-cad-suite-build/releases/download/${OSS_CAD_SUITE_DATE}/oss-cad-suite-linux-x64-${d}.tgz"; \
    echo "c64d557848d57fad96a5bea7461e12b3ddfb49514658f7301f7e1a5476128a88  /tmp/suite.tgz" \
      | sha256sum -c -; \
    tar -xzf /tmp/suite.tgz -C /opt; \
    rm /tmp/suite.tgz
# The Verible release directory and its bin/ are mode 700; uid 1001 must be able
# to traverse them or PATH search reports the binaries as "command not found".
RUN set -eux; \
    curl -fsSL -o /tmp/verible.tgz \
      "https://github.com/chipsalliance/verible/releases/download/${VERIBLE_VERSION}/verible-${VERIBLE_VERSION}-linux-static-x86_64.tar.gz"; \
    echo "ca83778c7c2b73272277bd670d1851c8caf973fd3283688aeb0d36d4b3598a90  /tmp/verible.tgz" \
      | sha256sum -c -; \
    tar -xzf /tmp/verible.tgz -C /tmp; \
    mv "/tmp/verible-${VERIBLE_VERSION}" /opt/verible; \
    chmod 0755 /opt/verible /opt/verible/bin; \
    rm /tmp/verible.tgz
RUN set -eux; \
    curl -fsSL -o /tmp/surfer.zip \
      "https://gitlab.com/api/v4/projects/42073614/packages/generic/surfer/${SURFER_VERSION}/surfer_linux_${SURFER_VERSION}.zip"; \
    echo "bfaa83a4b73e50ca3a4fd19d515b3beef34e781fa55765865bbcce696a183a4d  /tmp/surfer.zip" \
      | sha256sum -c -; \
    mkdir -p /opt/surfer; \
    unzip -q /tmp/surfer.zip -d /opt/surfer; \
    rm /tmp/surfer.zip

# ── Build the exact Verilator release (the suite ships 5.055-devel) ─────────
FROM ubuntu:26.04@sha256:6a06111c3b0a8600feadb270aec771dc239bf407b25625f93f44ab00e11f4d3c AS verilator-build
ARG VERILATOR_VERSION=5.054
ARG VERILATOR_COMMIT=bbb60a403932a9f695cb6ff001ceb73de6ad9234
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates git autoconf flex bison help2man make g++ perl python3 libfl-dev \
 && rm -rf /var/lib/apt/lists/*
RUN git clone --depth 1 --branch "v${VERILATOR_VERSION}" \
      https://github.com/verilator/verilator.git /src/verilator
RUN test "$(git -C /src/verilator rev-parse HEAD)" = "${VERILATOR_COMMIT}"
RUN cd /src/verilator \
 && autoconf \
 && ./configure --prefix=/opt/verilator \
 && make -j"$(nproc)" \
 && make install

# ── Build the exact Yosys release (the suite ships 0.70+336) ────────────────
FROM ubuntu:26.04@sha256:6a06111c3b0a8600feadb270aec771dc239bf407b25625f93f44ab00e11f4d3c AS yosys-build
ARG YOSYS_VERSION=v0.70
ARG YOSYS_COMMIT=28ba3cb926fe376fa05ebfc1b921747d011d4557
ENV DEBIAN_FRONTEND=noninteractive
# Yosys v0.70 builds with CMake (the Makefile was removed); >= 3.28 required.
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates build-essential clang lld cmake bison flex libfl-dev \
      libreadline-dev gawk tcl-dev libffi-dev git graphviz xdot pkg-config \
      python3 zlib1g-dev \
 && rm -rf /var/lib/apt/lists/*
RUN git clone --depth 1 --branch "${YOSYS_VERSION}" --recurse-submodules \
      --shallow-submodules https://github.com/YosysHQ/yosys.git /src/yosys
RUN test "$(git -C /src/yosys rev-parse HEAD)" = "${YOSYS_COMMIT}"
# Slang is disabled: it is a large submodule build, the suite's own Yosys (with
# slang) remains at /opt/oss-cad-suite/bin/yosys, and the QSOC flow uses
# read_verilog -sv.
RUN cmake -S /src/yosys -B /src/yosys/build \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_INSTALL_PREFIX=/opt/yosys \
      -DBUILD_SHARED_LIBS=OFF \
      -DYOSYS_ENABLE_UNIT_TESTS=OFF \
      -DYOSYS_WITHOUT_SLANG=ON
RUN cmake --build /src/yosys/build -j"$(nproc)" \
 && cmake --install /src/yosys/build

# ── Runtime image ───────────────────────────────────────────────────────────
FROM ubuntu:26.04@sha256:6a06111c3b0a8600feadb270aec771dc239bf407b25625f93f44ab00e11f4d3c AS eda
ARG UBUNTU_VERSION=26.04
ARG VERILATOR_VERSION=5.054
ARG YOSYS_VERSION=v0.70
ARG COCOTB_VERSION=2.1.0
ARG VERIBLE_VERSION=v0.0-4298-g085eef05
ARG SURFER_VERSION=v0.7.0

LABEL org.opencontainers.image.title="qnsc-eda" \
      org.opencontainers.image.description="Open-source EDA toolchain for the QNSC VLSI platform" \
      org.opencontainers.image.licenses="Multiple (see /opt/oss-cad-suite/license and each tool)" \
      org.opencontainers.image.base.name="docker.io/library/ubuntu:26.04" \
      org.opencontainers.image.base.digest="sha256:6a06111c3b0a8600feadb270aec771dc239bf407b25625f93f44ab00e11f4d3c" \
      vn.qnsc.toolchain.verilator="${VERILATOR_VERSION}" \
      vn.qnsc.toolchain.yosys="${YOSYS_VERSION}" \
      vn.qnsc.toolchain.cocotb="${COCOTB_VERSION}" \
      vn.qnsc.toolchain.verible="${VERIBLE_VERSION}" \
      vn.qnsc.toolchain.surfer="${SURFER_VERSION}"

ENV DEBIAN_FRONTEND=noninteractive
# Runtime libraries Yosys (built against readline/tcl/ffi) and the suite link.
# g++/make are runtime dependencies: Verilator and cocotb compile a C++ model
# every time they simulate.
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates curl git make g++ python3 python3-venv python3-yaml \
      perl emacs-nox jq passwd \
      libreadline8t64 tcl8.6 libffi8 zlib1g libstdc++6 \
 && rm -rf /var/lib/apt/lists/*

COPY --from=fetch /opt/oss-cad-suite /opt/oss-cad-suite
COPY --from=fetch /opt/verible /opt/verible
COPY --from=fetch /opt/surfer /opt/surfer
COPY --from=yosys-build /opt/yosys /opt/yosys
COPY --from=verilator-build /opt/verilator /opt/verilator

# cocotb 2.1.0 in its own venv.  The suite's Python is left untouched: the
# suite's own scripts (sby and friends) call tabbypy3 explicitly, and `python3`
# stays the distro interpreter the repo's make targets expect (venv, PyYAML).
RUN python3 -m venv /opt/cocotb \
 && /opt/cocotb/bin/pip install --no-cache-dir --disable-pip-version-check \
      "cocotb==${COCOTB_VERSION}"

# The pinned tools shadow the suite's rolling copies.  /usr/local/bin precedes
# /opt/oss-cad-suite/bin in PATH, and cocotb-config comes from the venv.
RUN set -eux; \
    ln -sf /opt/yosys/bin/yosys /usr/local/bin/yosys; \
    ln -sf /opt/yosys/bin/yosys-abc /usr/local/bin/yosys-abc; \
    ln -sf /opt/yosys/bin/yosys-config /usr/local/bin/yosys-config; \
    ln -sf /opt/verilator/bin/verilator /usr/local/bin/verilator; \
    ln -sf /opt/verilator/bin/verilator_bin /usr/local/bin/verilator_bin; \
    ln -sf /opt/verilator/bin/verilator_coverage /usr/local/bin/verilator_coverage; \
    for b in /opt/verible/bin/*; do ln -sf "$b" "/usr/local/bin/$(basename "$b")"; done; \
    ln -sf /opt/surfer/surfer /usr/local/bin/surfer; \
    ln -sf /opt/surfer/surver /usr/local/bin/surver; \
    ln -sf /opt/cocotb/bin/cocotb-config /usr/local/bin/cocotb-config

ENV PATH="/usr/local/bin:/usr/bin:/bin:/opt/oss-cad-suite/bin:/opt/oss-cad-suite/py3bin"
# VERILATOR_ROOT is deliberately NOT set: each verilator binary derives its
# root from its own install prefix.  Sourcing the suite's environment script
# would point it at the suite's 5.055-devel share tree.

COPY scripts/check-versions.sh /usr/local/bin/check-versions
COPY smoke /opt/smoke
RUN chmod 0755 /usr/local/bin/check-versions /opt/smoke/run.sh \
 && check-versions

RUN /usr/sbin/groupadd --gid 1001 eda \
 && /usr/sbin/useradd --uid 1001 --gid 1001 --create-home --shell /bin/bash eda
ENV HOME=/home/eda
WORKDIR /home/eda
USER 1001:1001

CMD ["/bin/bash"]
