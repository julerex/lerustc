# DirectRedox linkage and runtime entry model

For DirectRedox targets we configure fully static, no-crt ELF linkage with `entry_name = "runtime_entry"`, empty crt objects (self-contained), and a self-contained LLD (rust-lld) as the default linker. The DirectRedoxPal provides the `runtime_entry` symbol (modeled on hermit's pattern) that performs the minimal scheme/arg/env bootstrap using only redox_syscall before handing off to std's runtime and user main.

This was chosen over (a) reusing any relibc crt/startup code, (b) relying on the existing MulticallLinker/Wild (Linux-specific), or (c) requiring an external Redox-aware linker in the dist.

The model ensures every binary produced by the cross-compiler is a direct-executable SchemeNativeBinary with zero POSIX or libc dependencies, matches the "dependency-minimized" spirit of lerustc for the output artifacts, and keeps the host compiler's MulticallLinker unchanged. It is a significant, visible change to how user binaries are built for the new targets and will affect all downstream linking and startup code.