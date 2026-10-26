# CrossSmoke testing strategy for DirectRedox

The test harness (smoke.sh and friends) will be extended with an *optional* CrossSmoke path. When the DirectRedoxSysroot is present in the dist, a minimal program using the committed std surface is compiled for the direct target. If `redoxer` (or equivalent QEMU/Redox execution environment) is detected, the produced binary is run inside a Redox VM and its behavior (stdout, side effects) is asserted. If the runner is absent, compilation succeeds, a diagnostic note is printed, and the step does not fail the overall smoke.

This mirrors the existing optional busybox container smoke. The primary smoke remains strictly about the static Linux rustc artifact.

This was chosen over (a) making redoxer a hard requirement for any lerustc build/test, (b) only verifying that the cross compile succeeds without execution, or (c) adding full Redox CI infrastructure to the project.

The strategy provides a realistic, low-friction path to end-to-end validation of the new pal, runtime entry, and linkage while preserving the lean, Linux-centric character of the current smoke tests and the "optional exotic dependency" precedent already present in the harness. It introduces a new optional external tool in the test path and a new execution environment, which is visible to maintainers and CI authors.