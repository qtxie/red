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
| allocation-heavy Red program, two loops (string churn + block/string pairs) | 1 | ~7×10⁵ collect+verify cycles, identical output, exit 0 |
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

## Phase 3: the checks (generation 254)

- **The plan/emit coupling is pinned.** The has-call audit came out clean:
  every `OP_NATIVE` subop that can reach the runtime is covered
  (`STACK_ALLOCATE`/`STACK_FREE` fall inside the `STACK_TOP..STACK_FREE`
  range check, `STACK_PUSH_ALL`/`STACK_POP_ALL` have their own arm) and
  the remaining subops are pure instructions — `ATOMIC_*`
  (LDAXR/STLXR/DMB), `PROGRAM_COUNTER`, `CPU_OVERFLOW`, `CPU_REGISTER`
  reads, and `LOG_B`, which emits `clz`. There is no gating hole. The one
  desync that would silently disable the shadows — emit reaching a call
  site while plan counted none, so no shadow slot was ever reserved — is
  now a compile error: `OP_CALL` and `OP_SUB_CALL` refuse to spill when
  `plan/has-call = 0` (`compile-function/plan/has-call#222/#223`). It
  cannot fire on current code; it fails the build the day a future edit
  breaks the plan/emit correspondence. `OP_NATIVE` is deliberately
  unpinned: pure subops legitimately reach its spill site in has-call = 0
  functions.
- **A stressed collection verifies its own bookkeeping.** With
  `RED_GC_STRESS` set, `verify-compaction` (`runtime/collector.reds`) runs
  after every forced cycle, in release code: every live series buffer in a
  compacted frame must be pointed back at by its own node
  (`resolve-node`), `offset`/`tail` must stay inside the buffer, and every
  big series must agree with its node. Pinned frames are skipped — their
  dead series are still laid out in place. A violation prints the broken
  header and exits -1: a misbehaving stress run with this check passing
  points at generated or runtime code, not at the collector.

Measured with generation 254 (built by 253): x64 suite 10593 / 12680 /
0 failed, unchanged under `RED_GC_STRESS=400`; ARM64 suite 41 units /
12652 assertions / 0 failed; fixed point 254 → 255 → 256, 255 vs 256
differing in 5 bytes (PE timestamp, checksum, one output-name digit).

## Open items

- `_hashtable/get-ctx-symbol` buckets on the *resolved* key but compares
  the *unresolved* stored symbol, and `resize` re-buckets through a third
  formula (`runtime/hashtable.reds:2603-2697`, `:1531-1537`). Not proven to
  have fired, but it is the shape of bug that makes `words-of` and `in`
  disagree once per layout — the `#394` note in AGENTS.md.
- Darwin-ARM64 has not run the shadow-enabled suite (Linux-ARM64 is green,
  41 units / 12652 assertions / 0 failed; the spill code is ABI-independent,
  so the Mac run is confirmation, not exposure).
