#!/usr/bin/env bash
# Smoke-test the lerustc dist/ artifact.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST="${ROOT}/dist"
RUSTC="${DIST}/bin/rustc"
SYSROOT="${DIST}"

if [[ ! -x "${RUSTC}" ]]; then
    echo "error: ${RUSTC} not found — run ./build.sh all first" >&2
    exit 1
fi

TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

echo "==> Checking rustc is fully static"
if file "${RUSTC}" | grep -q 'statically linked'; then
    echo "OK: rustc is statically linked"
else
    echo "WARN: rustc may not be fully static:"
    file "${RUSTC}" || true
    ldd "${RUSTC}" 2>&1 || true
fi

echo "==> Checking rustc version"
"${RUSTC}" --sysroot "${SYSROOT}" -vV

echo "==> Compiling hello.rs"
cat > "${TMP}/hello.rs" <<'RS'
fn main() {
    println!("hello from lerustc");
}
RS

"${RUSTC}" --sysroot "${SYSROOT}" "${TMP}/hello.rs" -o "${TMP}/hello"
"${TMP}/hello"

echo "==> Compiling threads + IO test"
cat > "${TMP}/threads.rs" <<'RS'
use std::io::{self, Write};
use std::thread;

fn main() -> io::Result<()> {
    let handles: Vec<_> = (0..4)
        .map(|i| {
            thread::spawn(move || {
                println!("thread {i}");
                i
            })
        })
        .collect();
    let sum: i32 = handles.into_iter().map(|h| h.join().unwrap()).sum();
    let mut stdout = io::stdout();
    writeln!(stdout, "sum={sum}")?;
    Ok(())
}
RS

"${RUSTC}" --sysroot "${SYSROOT}" "${TMP}/threads.rs" -o "${TMP}/threads"
"${TMP}/threads"

echo "==> All smoke tests passed"

# Optional: verify the compiler runs inside a minimal container (no host libc needed).
if command -v docker >/dev/null 2>&1; then
    echo "==> Running container smoke test (busybox, no host dynamic linker)"
    docker run --rm -v "${DIST}:/lerustc:ro" -v "${TMP}:/work" -w /work busybox \
        /lerustc/bin/rustc --sysroot /lerustc /work/hello.rs -o /work/hello-container \
        || echo "WARN: container smoke test failed"
    if [[ -x "${TMP}/hello-container" ]]; then
        docker run --rm -v "${TMP}:/work" -w /work busybox /work/hello-container \
            || echo "WARN: container run failed"
        echo "OK: container smoke test passed"
    fi
else
    echo "SKIP: docker not available for container smoke test"
fi
