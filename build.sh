#!/usr/bin/env bash
# Build a dependency-free static rustc toolchain (lerustc).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUST_DIR="${ROOT}/rust"
DIST_DIR="${ROOT}/dist"
PATCH="${ROOT}/patches/lerustc.patch"
CONFIG="${ROOT}/bootstrap.toml"
RUST_COMMIT="$(tr -d '[:space:]' < "${ROOT}/RUST_COMMIT")"

export LERUSTC=1
export CG_CLIF_FORCE_GNU_AS=1
# Prefer a working rustup toolchain for bootstrap stage0 (avoid broken proxies).
if [[ -d "${HOME}/.rustup/toolchains/stable-x86_64-unknown-linux-gnu/bin" ]]; then
    export PATH="${HOME}/.rustup/toolchains/stable-x86_64-unknown-linux-gnu/bin:${PATH}"
    export RUSTUP_TOOLCHAIN=stable
fi

usage() {
    cat <<'EOF'
Usage: ./build.sh [command]

Commands:
  build     Clone/checkout rust, apply patches, build stage1 rustc + std (default)
  dist      Assemble dist/ from the build output
  all       build + dist
  clean     Remove rust/ checkout and dist/

Environment:
  LERUSTC=1              Enables lerustc patches at build time (set automatically)
  CG_CLIF_FORCE_GNU_AS=1 Use GNU as for cg_clif inline asm (set automatically)
  LERUSTC_MUSL_LINKER    Path to musl-gcc (default: search PATH and /usr/bin/musl-gcc)
  CARGO_BUILD_JOBS       Parallel cargo jobs (optional)
EOF
}

require_musl_gcc() {
    if [[ -n "${LERUSTC_MUSL_LINKER:-}" && -x "${LERUSTC_MUSL_LINKER}" ]]; then
        return 0
    fi
    if command -v musl-gcc >/dev/null 2>&1; then
        return 0
    fi
    if [[ -x /usr/bin/musl-gcc ]]; then
        return 0
    fi
    echo "error: musl-gcc not found (install musl-tools, e.g. apt install musl-tools)" >&2
    echo "       or set LERUSTC_MUSL_LINKER to a musl cross compiler" >&2
    exit 1
}

ensure_rust_repo() {
    if [[ ! -d "${RUST_DIR}/.git" ]]; then
        echo "==> Cloning rust-lang/rust at ${RUST_COMMIT}"
        git clone https://github.com/rust-lang/rust.git "${RUST_DIR}"
    fi

    pushd "${RUST_DIR}" >/dev/null
    git fetch origin "${RUST_COMMIT}" --depth 1 2>/dev/null || git fetch origin --depth 1
    git checkout -f "${RUST_COMMIT}"
    popd >/dev/null
}

apply_patches() {
    echo "==> Applying lerustc patches"
    pushd "${RUST_DIR}" >/dev/null
    # Reset to clean pinned commit before applying.
    git checkout -f "${RUST_COMMIT}"
    git clean -fdx -e /target 2>/dev/null || git clean -fdx
    if [[ -f "${PATCH}" ]]; then
        git apply --check "${PATCH}"
        git apply "${PATCH}"
    else
        echo "error: patch not found at ${PATCH}" >&2
        exit 1
    fi
    cp "${CONFIG}" config.toml
    popd >/dev/null
}

update_lockfile() {
    echo "==> Updating Cargo.lock for libwild dependencies"
    pushd "${RUST_DIR}" >/dev/null
    # Resolve new rustc-main dependencies into the workspace lockfile.
    ./x.py check --stage 0 compiler/rustc 2>/dev/null || \
        cargo generate-lockfile --manifest-path compiler/rustc/Cargo.toml 2>/dev/null || true
    popd >/dev/null
}

build_rustc() {
    require_musl_gcc
    pushd "${RUST_DIR}" >/dev/null
    echo "==> Phase 1: stage1 gnu compiler (bootstrap cross-compiler)"
    ./x.py build --stage 1 --host x86_64-unknown-linux-gnu compiler
    echo "==> Phase 2: musl std (cross-compiled with stage1 gnu)"
    ./x.py build --stage 1 --host x86_64-unknown-linux-musl library
    echo "==> Phase 3: static musl-host rustc"
    ./x.py build --stage 1 --host x86_64-unknown-linux-musl compiler
    popd >/dev/null
}

assemble_dist() {
    local build_triple host stage_dir rustc_bin stage
    build_triple="x86_64-unknown-linux-gnu"
    host="x86_64-unknown-linux-musl"
    for stage in 2 1; do
        rustc_bin="${RUST_DIR}/build/${build_triple}/stage${stage}-rustc/${host}/release/rustc-main"
        if [[ -f "${rustc_bin}" ]]; then
            break
        fi
    done
    if [[ ! -f "${rustc_bin}" ]]; then
        echo "error: static musl rustc not found under rust/build/${build_triple}/stage*-rustc/${host}" >&2
        exit 1
    fi
    stage_dir="${RUST_DIR}/build/${build_triple}/stage1"

    echo "==> Assembling dist/ for ${host}"
    rm -rf "${DIST_DIR}"
    mkdir -p "${DIST_DIR}/bin" "${DIST_DIR}/lib"

    cp "${rustc_bin}" "${DIST_DIR}/bin/rustc"
    chmod +x "${DIST_DIR}/bin/rustc"

    if [[ -d "${stage_dir}/lib/rustlib" ]]; then
        cp -a "${stage_dir}/lib/rustlib" "${DIST_DIR}/lib/"
    else
        echo "error: sysroot rustlib not found at ${stage_dir}/lib/rustlib" >&2
        exit 1
    fi

    cat > "${DIST_DIR}/README.txt" <<EOF
lerustc distribution
host: ${host}
rustc: ${DIST_DIR}/bin/rustc
sysroot: ${DIST_DIR}
libc: musl (static)

Usage:
  ${DIST_DIR}/bin/rustc --sysroot ${DIST_DIR} -o hello hello.rs

Limitations:
  - No custom proc macros (static binary cannot dlopen proc-macro dylibs)
  - Nightly compiler, Linux x86_64 only
  - Inline asm in user code requires GNU 'as' on PATH (CG_CLIF_FORCE_GNU_AS)
EOF

    echo "==> dist ready at ${DIST_DIR}"
    ls -lh "${DIST_DIR}/bin/rustc"
    file "${DIST_DIR}/bin/rustc" || true
    ldd "${DIST_DIR}/bin/rustc" 2>&1 || true
}

clean() {
    rm -rf "${RUST_DIR}" "${DIST_DIR}"
    echo "==> cleaned rust/ and dist/"
}

cmd="${1:-all}"
case "${cmd}" in
    build)
        ensure_rust_repo
        apply_patches
        update_lockfile
        build_rustc
        ;;
    dist)
        assemble_dist
        ;;
    all)
        ensure_rust_repo
        apply_patches
        update_lockfile
        build_rustc
        assemble_dist
        ;;
    clean)
        clean
        ;;
    -h|--help|help)
        usage
        ;;
    *)
        echo "unknown command: ${cmd}" >&2
        usage >&2
        exit 1
        ;;
esac
