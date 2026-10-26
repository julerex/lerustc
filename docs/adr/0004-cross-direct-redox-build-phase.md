# CrossDirectRedox build phase and sysroot integration

We extend the existing 3-phase lerustc build (stage1 gnu, musl std, static musl-host rustc) with a fourth phase: after the host compiler exists, cross-compile the library for the new DirectRedox target(s) using that host compiler, then copy the resulting rustlib/<triple> trees into the dist sysroot during assemble_dist.

bootstrap.toml is updated to declare the new target(s), and the patch set receives only the minimal changes needed to allow std to build for env=direct.

This was chosen over (a) building a separate DirectRedox-hosted rustc in the same dist, (b) requiring users to run x.py themselves for the cross std, or (c) baking the DirectRedox rlibs into the same "host" rustlib tree.

The approach preserves the current "one static Linux multicall rustc + sysroot" shape and value proposition of lerustc while adding the cross capability as a clean, optional extension. The primary artifact and its MulticallLinker/BuiltinCodegen characteristics remain untouched; only the sysroot grows. This is a visible change to the build script and dist layout that future maintainers will notice.