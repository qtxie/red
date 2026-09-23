# Self-hosting transition tools

`selfhost.py` is a transitional verification tool, not a replacement compiler.
It has two jobs while the Red implementation is being reworked:

* `inventory` records every tracked Red/Rebol source, its hash, classification,
  literal file references, and target/format registry facts.
* `diff` runs two compiler commands against the same corpus and preserves raw
  stdout, stderr, and output artifacts while comparing normalized results.

The compiler entrypoints are `red-bootstrap-hybrid.red` (full Red + Red/System
driver, development mode by default, `-r` for standalone release builds) and
`red-system-hybrid.red` (Red/System-only). The standalone toolchain entry is
`red-toolchain-hybrid.red`; `tools/self_hosting/build-red-toolchain.red` is the
supported way to build it. The legacy Rebol-era drivers (`red.r`,
`red-bootstrap-windows.red`, and the per-platform selfhost entries) are gone;
the hybrid RSIR pipeline is the only compiler in the tree.

The compiler executable is built in release mode without `-d`; this avoids
embedding several megabytes of compiler source-line metadata. It still accepts
`-d` when debug information is required in the program being compiled.

Build the standalone Windows x64 hybrid toolchain from that compiler with:

```powershell
& .\tools\self_hosting\build-windows-hybrid-toolchain.ps1
```

The build embeds the runtime, modules, View sources, and assets, then validates
the resulting PE image and resource archive. Verify repository-independent
release, development, module, Red/System, DLL, and View compilation with:

```powershell
& .\tools\self_hosting\test-windows-hybrid-toolchain.ps1 `
    -Toolchain .\build\red-toolchain\windows-x64\red-toolchain.exe
```

For the release gate, build H1, H2, and H3 through one canonical staging path
and require a normalized H2/H3 PE fixed point before running the same hermetic
suite with H3. `SOURCE_DATE_EPOCH` defaults to the current Git commit timestamp:

```powershell
& .\tools\self_hosting\test-windows-hybrid-toolchain-fixed-point.ps1
```

Use the benchmark wrapper for a single profiled release/debug `hello.red` run:

```powershell
& .\tools\self_hosting\benchmark-compiler.ps1 `
    -Compiler .\build\self-hosting\cc-speed1\red-bootstrap-speed1.exe `
    -Runs 1 `
    -OutputRoot .\build\compiler-benchmarks
```

The wrapper verifies the generated executable and writes raw logs, phase data,
hashes, memory use, and a JSON report below the output directory.

Use `benchmark-generated-code.ps1` to compare emitted-program runtime. Linux x64
programs built by a Windows-hosted compiler can run through one persistent WSL
driver, which excludes WSL startup from every timed sample:

```powershell
& .\tools\self_hosting\benchmark-generated-code.ps1 `
    -Compiler .\build\self-hosting\red-bootstrap-linux-x64.exe `
    -Source .\tools\self_hosting\fixtures\benchmarks\integer-loop.reds `
    -Target Linux-X86-64 `
    -Optimizations O0,O2 `
    -ProgramRuntime WSL `
    -Runs 31
```

The harness verifies exit status, stdout, and stderr before warmup, rotates the
optimization order for interleaved samples, and records wall time, CPU time,
compiler and source hashes, target, WSL platform, and paired speedups in
`report.json`. Use `-WslDistribution NAME` when the default distribution is not
the intended test environment.

For a focused Red/System check, compile the fixture directly with a bootstrap
compiler and pass the target explicitly:

```powershell
& .\build\self-hosting\merge-red64\hybrid-compiler202.exe `
    -r -t MSDOS-X86-64 `
    -o .\build\case-control-O2.exe `
    .\tools\self_hosting\fixtures\backend\case-control.reds
```

Run compiler invocations serially: check that the previous compiler process has
exited before starting another one.

No `build.r`, pre-cap, encap, Rebol executable, or `red.r` invocation is
involved in the normal self-hosted build.

Example:

```text
python tools/self_hosting/selfhost.py inventory --output build/self-hosting/source-manifest.json
python tools/self_hosting/selfhost.py verify build/self-hosting/source-manifest.json
python tools/self_hosting/selfhost.py verify tools/self_hosting/source-baseline.json
python tools/self_hosting/selfhost.py target-registry
```

The old Windows Stage0 oracle configurations are retained only for an explicitly
requested historical audit. Do not run them during normal development:

```text
python tools/self_hosting/selfhost.py diff tools/self_hosting/oracle-selfcheck.windows.json --work-root build/self-hosting/oracle-runs --report build/self-hosting/oracle-report.json
```

The target matrix covers all current CPU classes and PE, ELF, and Mach-O:

```text
python tools/self_hosting/selfhost.py diff tools/self_hosting/oracle-matrix.windows.json --work-root build/self-hosting/oracle-matrix-runs --report build/self-hosting/oracle-matrix-report.json
```

The command configuration is intentionally explicit. New parity configurations
must compare self-hosted generations and must not introduce an encap cache or a
Rebol build script.

`fixtures/host-contract/dynamic-object-method.red` records a known interpreter /
compiled-Red divergence for an object method injected through a slot initially
set to `none`. It is a future Red compiler regression test; bootstrap compiler
services currently use statically declared object shapes as documented in
`red-self-hosting-plan.md`.
