# GC raw-pointer staleness audit

Compaction moves live buffers. Every raw pointer held across an allocation
is a potential read of freed memory; the node handles survive (the collector
updates `node/value`), raw addresses do not. This document records the
audit's vehicle, what it has found and fixed, and what is still open.

## The vehicle: `RED_GC_STRESS`

`runtime/collector.reds` reads the env var at init and
`runtime/allocator.reds` runs a full collect cycle every Nth allocation
while it is set (`=1` means every allocation); while stressed, freed
compaction regions are poisoned like a debug build's. Layout-dependent
flakes become immediate failures.

Measured so far, all green:

| workload | period | result |
|---|---|---|
| allocation-heavy Red program (append/map/collect) | 1 and 20 | identical output, exit 0 |
| the compiler itself, full `hello.red` compile | 300 | exit 0, output runs |
| the whole Red/System unit suite (41 units, compile+run) | 400 | 10593 / 12680 / 0 failed / 0 compile-failures |

## What the audit has caught and fixed

1. **Global map entries lost under GC pressure** (linux-arm64,
   length-dependent compile failures, commits `7767c4352` + `2ccb691c9`):
   `runtime/hashtable.reds`, `runtime/datatypes/map.reds`,
   `runtime/ownership.reds` — table series re-resolved after every
   allocation that could move them.

2. **ARM64 register-homed pointer locals across calls** (commit
   `203393492`): X19-X28 locals survive the call per the ABI, the data they
   point to does not survive the collector. Pointer-typed register-homed
   locals now have a collector-visible shadow frame slot; every call spills
   and reloads around it. x64 needed nothing — its locals all live in
   bitmap-marked slots. The expression-spill windows were already covered:
   the collector gap-scans them (`collector.reds:1604-1623`).

3. **The `-v N>=1` UNTIL failure** (commit `f0ebd9896`) — the one that once
   looked like a GC catch and was not: the red-pass's
   `[------------| "source"]` position markers were expanded to `print-line`
   calls by a verbosity-conditional runtime macro, and stack-block's keep?
   check dropped a trailing value whenever a (now comment) pair followed
   the last statement. Deterministic, any layout; recorded here because it
   consumed audit time and because its repro (`-v 4` on any Red program)
   is the standing example of a trigger that is *not* memory-layout.

## Standing rule for the two backends

- x64: locals in frame slots; the bitmap must cover every slot a pointer
  can reach. Expression temps are caller-saved and spill to marked slots
  around calls by construction.
- ARM64: register-homed pointer locals must not outlive a call without
  their shadow slot. `bitmap-marked-type?` mirrors the bitmap's marking
  decision; a new type that the bitmap marks must be added there too, or
  the shadow is silently not taken.

## Open items

- `_hashtable/get-ctx-symbol` buckets on the *resolved* key but compares
  the *unresolved* stored symbol, and `resize` re-buckets through a third
  formula (`runtime/hashtable.reds:2603-2697`, `:1531-1537`). Not proven to
  have fired, but it is the shape of bug that makes `words-of` and `in`
  disagree once per layout — the `#394` note in AGENTS.md.
- Phase 3 of the plan (debug-build assertions in the runtime's series
  accessors plus a static RSIR pass that flags pointer-typed
  register-homed locals live across calls without a shadow) is not built.
  The shadow mechanism makes the static check mechanical; the debug
  assertions make stress runs name the faulting site.
- Darwin-ARM64 has not run the shadow-enabled suite (Linux-ARM64 is green,
  41 units / 12652 assertions / 0 failed; the spill code is ABI-independent,
  so the Mac run is confirmation, not exposure).
