# Self-hosting transition tools

`selfhost.py` is a transitional verification tool, not a replacement compiler.
It has two jobs while the Red implementation is being reworked:

* `inventory` records every tracked Red/Rebol source, its hash, classification,
  literal file references, and target/format registry facts.
* `diff` runs two compiler commands against the same corpus and preserves raw
  stdout, stderr, and output artifacts while comparing normalized results.

The direct compiler entrypoint is `red-selfhost.red`. It is compiled with the
repository's documented Stage 0 command; this tool only verifies its source
closure and compares later stages.

The transition build produces an ordinary executable directly:

```text
cmd /c D:\EE\QTool\rebcmdview.exe -cqs ./red.r -r -d -o build/self-hosting/red-selfhost.exe red-selfhost.red
build\self-hosting\red-selfhost.exe --check-all
```

Once Stage 1 exists, replace the compiler executable in that command with the
Stage 1 binary. No `build.r`, pre-cap, or encap step is involved.

Example:

```text
python tools/self_hosting/selfhost.py inventory --output build/self-hosting/source-manifest.json
python tools/self_hosting/selfhost.py verify build/self-hosting/source-manifest.json
python tools/self_hosting/selfhost.py verify tools/self_hosting/source-baseline.json
python tools/self_hosting/selfhost.py target-registry
```

The Windows Stage 0 smoke corpus uses the documented Rebol compiler only as
an oracle and keeps both output trees for inspection:

```text
python tools/self_hosting/selfhost.py diff tools/self_hosting/oracle-selfcheck.windows.json --work-root build/self-hosting/oracle-runs --report build/self-hosting/oracle-report.json
```

The target matrix covers all current CPU classes and PE, ELF, and Mach-O:

```text
python tools/self_hosting/selfhost.py diff tools/self_hosting/oracle-matrix.windows.json --work-root build/self-hosting/oracle-matrix-runs --report build/self-hosting/oracle-matrix-report.json
```

The command configuration is intentionally explicit.  A future Red Stage 1
uses the same corpus and replaces only the `right.command` definition; it does
not introduce an encap cache or a Rebol build script.

`fixtures/host-contract/dynamic-object-method.red` records a known interpreter /
compiled-Red divergence for an object method injected through a slot initially
set to `none`. It is a future Red compiler regression test; bootstrap compiler
services currently use statically declared object shapes as documented in
`red-self-hosting-plan.md`.
