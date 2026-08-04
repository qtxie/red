# Self-hosting transition tools

`selfhost.py` is a transitional verification tool, not a replacement compiler.
It has two jobs while the Red implementation is being reworked:

* `inventory` records every tracked Red/Rebol source, its hash, classification,
  literal file references, and target/format registry facts.
* `diff` runs two compiler commands against the same corpus and preserves raw
  stdout, stderr, and output artifacts while comparing normalized results.

The direct compiler entrypoint is `red-bootstrap-windows.red`. The canonical
Windows x64 compiler is the fixed-point self-hosted binary at
`build/self-hosting/red-bootstrap-stage1-x64-gc-fixed.exe`; this tool only
verifies its source closure and compares compiler generations.

The transition build produces an ordinary executable directly:

```powershell
$compiler = Resolve-Path .\build\self-hosting\red-bootstrap-stage1-x64-gc-fixed.exe
& $compiler -r -t Windows-X86-64 `
    -o build\self-hosting\red-bootstrap-next-x64.exe `
    red-bootstrap-windows.red
```

The compiler executable is built in release mode without `-d`; this avoids
embedding several megabytes of compiler source-line metadata. It still accepts
`-d` when debug information is required in the program being compiled.

Use the benchmark wrapper for a single profiled release/debug `hello.red` run:

```powershell
& .\tools\self_hosting\benchmark-compiler.ps1 `
    -Compiler .\build\self-hosting\red-bootstrap-stage1-x64-gc-fixed.exe `
    -Runs 1 `
    -OutputRoot .\build\compiler-benchmarks
```

The wrapper verifies the generated executable and writes raw logs, phase data,
hashes, memory use, and a JSON report below the output directory.

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
