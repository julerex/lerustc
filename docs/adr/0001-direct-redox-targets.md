# Direct Redox targets as distinct built-in triples

We introduce new built-in target triples starting with `x86_64-unknown-redox-direct` (and later arches) that use `os = "redox"` and a new `env = "direct"`.

This was chosen over (a) mutating the semantics of the existing `*-unknown-redox` triples or (b) relying only on custom target JSONs shipped alongside lerustc.

The decision keeps the documented, CI'd, and relibc-dependent RelibcRedox targets completely untouched while making the new libc-free DirectRedox environment a discoverable, first-class target inside the patched rustc (visible to `--print target-list`, sysroot layout, etc.). It follows the established pattern of using `target_env` (and dedicated spec files) to differentiate environments on the same OS, as done for wasi p1/p2/p3, sgx, etc. The cost (new triple namespacing, additional maintenance in the patch set) is accepted because the alternative would either break existing Redox users or make the direct path second-class.