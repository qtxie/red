# Handover: GC roots, evaluation-test compile + runtime (r151)

**Date:** 2026-07-24
**Policy:** Root-cause fix in runtime / compiler / tools (not test patches).
**Binary:** `build/self-hosting/red-bootstrap-stage1-r154.exe`

## Status summary

| Gate | Result |
|------|--------|
| series-test compile | PASS |
| evaluation-test compile | PASS |
| evaluation-test run (Stage1) | **294/294** |
| evaluation-test run (Stage0 / Rebol host) | **294/294** |
| map literal `#[a: 3]` | PASS |

## A. Series-test intermittent GC (runtime/collector.reds)

**Symptom:** AV / freed handle / `tail does not allow none!` under GC while compiling series-test.

**Root cause:** multi-word stack bitmap walk stopped early when remaining bits were 0 → misaligned `idx`; HT tables shallow-kept across `do-node-cycle`.

**Fix:** always consume 31 bit positions per word; `mark-hashtable-node` + deep mark; re-enable `do-node-cycle` on IA-32; typo `'IA-32'` → `'IA-32`.

## B. evaluation-test compile crash `freed series handle: -1`

**Symptom:** permanent halt compiling `repend/:only` / evaluation-test.

**Root cause:** `foreach [ref-name idx nb] dyn-list` in `comp-call` → Stage1 `foreach-next-block` saw misaligned stack; “series” was an **object with class=-1** (not a freed handle).

**Fix:** replace 3-word foreach with `while` + `skip 3` in:
- `compiler/frontend.red`
- `encapper/compiler.r`

## C. evaluation-test runtime `fetched has no value` (environment/tools.red)

**Symptom:** crash on high-level `trace` (`get` of unbound word `fetched`).

**Root cause:** Stage1 does **not bind words inside object-literal blocks / nested methods**. `get word` / bare fields in `system/tools/tracers/data` looked up globals.

**Fix:** rewrite tracer collector / save-level / unroll-level / inspect to use:
- explicit fields or `system/tools/tracers/data/...` paths
- `append/only` / `take/last` instead of sibling `push`/`pop` helpers
- full paths for `emit`, `mold-part`, inspector fields

## D. Map literals `#[k: v]` became blocks (compiler/frontend.red)

**Symptom:** `#[a: 3]` → `block! [3]`; `map/a: ()` → `cannot set none in path map/a`.

**Root cause:** redbin `TYPE_MAP` via `#!map!` marker unreliable under Stage1; `map/push get-root` copied a block cell.

**Fix:** emit body as plain block, construct at runtime:
```
map/push map/make null as red-value! get-root (emit-block body) 0
```
`make map! [a: 3]` already worked.

## E. dyn-ref-5 / context-local words (Stage1 only — Stage0 never failed)

**Question:** does Stage0 fail? **No.** Stage0 evaluation-test is 294/294.

**Stage1 root cause:** tests wrap `scan: no` in `context [...]` to protect the global `scan` mezzanine. Stage1 often leaves body words **unbound** after load, so `emit-get-word` / `emit-push-from` used the **global** `scan` function (truthy) → `transcode/:scan` always enabled `/scan` → returned `word!` instead of `[hi]`.

**Fix (`compiler/frontend.red`):**
1. `emit-push-from`: if `binding-of` misses, fall back to current `obj-stack` object + `select-obj` + `get-word-index`.
2. `emit-get-word`: pass `original` (not unbound `name`) into `emit-push-from` so binding/obj-stack can apply; keep `get-word/get` only at true global root (`1 = length? obj-stack`).
3. `comp-set-word`: same obj-stack fallback for `obj-bound?` / `word/set-in`.

## Residual

1. Intermittent `*** GC-BUG get-ctx-symbol: symbols handle is 0` under heavy compile pressure.
2. Bare get-word print inside some context probes may still look global while path/dyn-ref and suite asserts are correct (full suite green).

## Verify

```
build\self-hosting\red-bootstrap-stage1-r154.exe -r -d -o out.exe tests\source\units\evaluation-test.red
out.exe
# expect 294/294

# Stage0 comparison:
# rebcmdview -cqs ./red.r -r -d -o stage0.exe tests/source/units/evaluation-test.red
```

)
