# Dedicated DirectRedox platform abstraction layer and minimal std surface

We will implement std support for DirectRedox targets by adding a new top-level directory `library/std/src/sys/pal/redox/` (parallel to hermit/, wasi/, uefi/, etc.) instead of extending the existing `unix/` pal with additional cfg gates.

A conditional dependency on `redox_syscall` (rustc-dep-of-std) will be added in std/Cargo.toml under the `all(target_os = "redox", target_env = "direct")` cfg.

The initial supported surface (MinimalDirectStdSurface) is core + alloc + panic + scheme-based I/O (stdio and fs using native Redox paths), env, and args — sufficient for `println!` and basic file scheme operations. Threads, process, and full POSIX-like APIs are deferred.

This was chosen over (1) cramming the implementation into the shared unix/ tree (which assumes libc and POSIX semantics throughout) or (2) shipping only a no_std + redox_syscall facade with no std at all.

The dedicated pal keeps the two Redox worlds (Relibc vs. direct) from contaminating each other, follows the established pattern for platforms with incompatible OS interfaces, and lets the cross-compiler produce immediately runnable simple programs while keeping the implementation surface small and focused for the first milestone. The entry point bootstrap will live in this pal as DirectRedoxRuntimeEntry.