# Handover: Stage1 self-hosting suite / IR parity

**Date:** 2026-07-26
**Branch:** `red-64` (local commits ahead of origin)
**Policy:** Root-cause compiler/runtime fixes; prefer Stage0 emission shapes; no Stage1-only context pins.
**Working Stage1 binary:** `build/self-hosting/red-bootstrap-stage1.exe`
**Recent commit:** `6bf94e6c6` - Stage1 object bindings and libRedRT dev mode

## Status summary

| Gate | Stage1 | Stage0 |
|------|--------|--------|
| evaluation-test | **294/294** | 294/294 |
| object-test | **652/652** | 652/652 |
| series-test | **1119/1119** | green |
| function-test | **147/147** | green |
| comparison-test | **558/558** | 558/558 |
| preprocessor-test | **21/21** | green |
| Core suite batch (~61) | **~52 PASS** | — |
| redbin-codec-test | **1762/1762** | **1762/1762** |
| parse-test | **1455/1455** (libRedRT dev mode) | 1455/1455 baseline |
| recycle-test | compile succeeds | green |
| case-folding-test | **192/192** | green |
| lexer-test | **929/929** | green |
| json/csv-test | module not found | modules wired in Stage0 |
| Stage2 self-host | broken historically | n/a |

Batch logs: `build/self-hosting/unit/suite/summary.txt`, `*.log`.

The failure investigations below are retained as historical debugging context.
The redbin, parse, recycle compile, case-folding, and lexer failures listed in
those sections have since been fixed.

## What landed recently (map + frontend)

### Map literals `#[k: v]` (fixes compare-map-1 / #5259)

**Was wrong:** nested/literal maps encoded without `#!map!` at **series head** (`insert` returns after the marker), so redbin wrote plain blocks; `type? #[x: 1]` became `block!`, mold like `[1]`. Suite could false-pass `<>` as block inequality.

**Fix:**
- `compiler/redbin-emitter.red`: `body: head insert copy to block! item #!map!` before `emit-block`; sturdier marker check; sticky `object-with-ctx` for #2920.
- `compiler/frontend.red`: map literals emit Stage0 shape
  `map/push as red-hash! get-root (emit-block [#!map! ...])`
  (`#!map!` is **only** an internal redbin marker; Stage1 loads real `map!` values.)

**Verified:** expr / nested / empty `#[]` / `#[x: #(none)]` all `map!`; comparison-test **558/558**.

### Other frontend pieces in same commit

- `is-object?`: **last** registry match (name reuse / inherit chains).
- `inherit-functions`: decorate via object **ctx** (`pos/2`), Stage0-like `repend functions` + skip duplicate bodies.
- Sticky `compiler-redbin-emitter/object-with-ctx` around object body compile (#2920) — **not** `ctx-stack`.
- `find/same` for Stage1 refinement detection (`try/:all`, `get`/`set` flags). Leave Stage0 `encapper/compiler.r` plain `find` (Rebol has no `find/same`).
- `stack/unroll-to` in `runtime/stack.reds` — Stage1 epilog still needs multi-frame pop (pure `unwind-last` AVs on large bootstrap).

## redbin-codec-test: why still red (not maps)

### Minimal repro (Stage1 only)

```red
///: load/as save/as none :// 'redbin 'redbin
8 /// 3   ; Stage0 -> 2, Stage1 -> Script Error: a has no value (Where: mod)
```

`//` is `make op! :modulo` (`environment/operators.red`). Body:

```red
r: mod a absolute b
either any [a - r = a r + b = b][0][r]
```

### Stage0 vs Stage1 after redbin of `://`

| Check | Stage0 | Stage1 |
|--------|--------|--------|
| live `8 // 3` | 2 | 2 |
| after roundtrip `8 /// 3` | **2** | **`a has no value`** |
| `context?` of body word `a` | **`[a b local r]`** (function ctx) | **global `system/words`** |
| compact bin size | **463** | **423** (-40) |

Root cause class: **function/op body arg rebinding after redbin decode** (args land on global ctx). Not map emission. Same `runtime/redbin.reds` encode-op/decode-op; Stage1 image function/context shape or encode path drops ~40 bytes of context payload.

### Bisect

- Values group through **object** (~line 360): PASS (~1344 asserts).
- Including **op** section (`///: test ://`, `8 /// 3`): FAIL with mod/`a` error.
- Isolated map roundtrips: PASS.

### Why hard

1. Symptom points at `mod` / assert; real bug is **context rebind** on op! -> function! redbin.
2. Double wrap: TYPE_OP + subtype function + context/symbols/references (`#4563` TBD in redbin).
3. Same codec source; Stage0 vs Stage1 **in-memory function/context** (and/or GC/handles) differ — encode walks live cells.
4. Full suite is large; iterate on the 5-line probe, not 1762 asserts.

### Fix direction (not done)

- Diff Stage0 vs Stage1 compact redbin for `://` (missing context/reference records).
- Trace `encode-function` / `decode-function` / context word binding for mezzanine ops under Stage1 image.
- Confirm whether Stage1 env construction of `modulo`/`//` already differs before encode.

## Other residual suite failures

| Test | Class | Notes |
|------|--------|------|
| parse-test | frontend binding | `PARSE - invalid rule: macros` near `expand-directives/clean [[] #macro word!]` |
| recycle-test | Stage1 compile AV | ~`0046FADD` while compiling |
| case-folding-test | GC/handle | `freed series handle` after frontend |
| lexer-test | frontend | `type/1` on word! in `comp-context` / dialect |
| json-test / csv-test | modules | `module not found` under Stage1 bootstrap |
| functions-test | harness | name only; `function-test` already green |

## Runtime allowlist / do-not

**Keep (from prior GC work):** collector stack-handle + `flag-gc-scan`; allocator resolve hardening; hashtable re-resolve (**no pin**); crush; system/reactivity/tools Stage1 paths.

**Drop / avoid:** context/hashtable pins; object multi-inherit rebind hacks; treating interpreter `call-top` unwind as the permanent frame fix (experimented; not sufficient alone). Unstaged `runtime/interpreter.reds` call-top experiment should stay out of commits unless proven.

**`stack/unroll-to`:** pragmatic Stage1 epilog until call-frame leaks fixed; Stage0 classic is `stack/unwind-last`. Long-term: find leaks, restore `unwind-last`, delete `unroll-to`.

**Red `context?` = Rebol `bind?`:** call `context?` directly; no fabricated `bind?` routine.

## Key files

| Area | Path |
|------|------|
| Stage1 frontend | `compiler/frontend.red` |
| Redbin emitter | `compiler/redbin-emitter.red` |
| Lexer adapter | `compiler/lexer.red` |
| Runtime redbin codec | `runtime/redbin.reds` |
| Stack / epilog | `runtime/stack.reds` |
| Ops | `environment/operators.red`, `environment/functions.red` (`mod`/`modulo`) |
| Bootstrap | `red-bootstrap-windows.red` |
| Stage0 host compiler | `encapper/compiler.r` (do not invent Red-only `find/same` there) |

## Verify commands

```bat
REM Rebuild Stage1 (Rebol host)
D:\EE\QTool\rebcmdview.exe -cqs ./red.r -r -o build/self-hosting/red-bootstrap-stage1.exe red-bootstrap-windows.red

REM Map / comparison
build\self-hosting\red-bootstrap-stage1.exe -r -o build\self-hosting\unit\suite\comparison-test.exe tests\source\units\comparison-test.red
build\self-hosting\unit\suite\comparison-test.exe
REM expect 558/558

REM Minimal op redbin regression (Stage1 currently fails)
REM ///: load/as save/as none :// 'redbin 'redbin
REM print try [8 /// 3]
REM Stage0: 2 ; Stage1: a has no value
```

Quick interpret (no long compile): `D:\EE\QTool\red-console.exe script.red` — watch for hung console CPU.

## Suggested next order

1. **redbin op/function context rebind** — minimal `://` probe; Stage0 vs Stage1 bin + `context?` of body args.
2. **parse-test / macros** — binding/emission for preprocessor object fields (not runtime parse).
3. Compile stability: recycle AV, case-folding freed handle, lexer `type/1`.
4. Modules JSON/CSV for Stage1 bootstrap if those units are required.
5. IR parity corpus Stage0 vs Stage1; only then claim suite green = parity.
6. Call-frame leaks -> drop `unroll-to` -> Stage2 (`tracing?`, ns resolution).

## Notes / non-goals

- d85b port tree was planned then **reverted**; not current baseline.
- Operator decoration may stay Red-native (`~op_add`); normalize in IR compares.
- Do not push object ctx onto `ctx-stack` for body literals (breaks `find-contexts` / `emit-deep-check`).
- Prefer Stage0 algorithm fidelity over permanent Stage1-only band-aids.
'''
