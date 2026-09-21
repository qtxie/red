# Hybrid Codegen Diagnostics

The native generators return a byte count on success and a negative status on
failure. The Red bridge maps these to its public status codes:

| Native | Bridge | Meaning |
| --- | --- | --- |
| -1 | 2 | `INVALID_IR`: a defined RSIR rule was violated |
| -2 | 3 | `UNSUPPORTED`: an unimplemented target feature or configuration |
| -3 | 4 | `OUTPUT_FULL`: the caller's output buffer must grow |
| -4 | 5 | `INTERNAL_ERROR`: inconsistent compiler state or rejected encoding |
| -5 | 6 | `RESOURCE_LIMIT`: arithmetic, layout, or implementation limit |
| -6 | 7 | `OUT_OF_MEMORY`: allocation failed |

Bridge status 1 denotes invalid API arguments; status 0 denotes success.
Only bridge status 4 is retryable. Its diagnostic carries the required and
available byte counts. `finish-code` grows to at least the requested size,
subject to `MAX-CODE-BYTES`, and prints a diagnostic only on final failure.

## Recording Failures

Each backend has small `fail-invalid`, `fail-unsupported`, `fail-internal`,
`fail-limit`, and `fail-memory` helpers. They take a backend-local site ID and a
literal source anchor. `fail-output` and `fail-mismatch` additionally take
required/expected and available/actual values.

`codegen-diag` preserves the first committed failure until `generate` resets it.
Callers propagate that status; they must not replace the original category or
location. `fail-code` preserves a recorded failure and captures an otherwise
unrecorded encoder failure at the caller's annotated check.

Primitive encoders distinguish rejected operands (`-1`) from insufficient
capacity (`BUFFER_FULL`, `-3`). They do not record diagnostics: rejected encoding
probes may legitimately select another encoding. Once codegen commits to an
encoding, either failure is an internal error. Functions are measured before
emission and receive a slice of exactly their measured size; exceeding that
slice cannot be repaired by enlarging the whole module buffer.

The record snapshots phase, function/instruction indexes, opcode and operands
only when a failure occurs. Validated module metadata supplies the function
name and, when present, the nearest preceding source line in the same function.
Source lookup is a binary search performed only on failure. Input text is
borrowed from the IR buffer, which must remain alive through reporting.
Missing source metadata is omitted. Diagnostics are allocation-free records;
there is no additional validation pass or exception mechanism.

## Locating And Auditing

```text
python tools/codegen/sync-codegen-sites.py --locate arm64:283
python tools/codegen/sync-codegen-sites.py --locate compile-function/member-operands
python tools/codegen/sync-codegen-sites.py --check
```

The locator prints the current source `file:line`. IDs and literal anchors are
retained across edits; compiler source line numbers are not permanent identities.
Use the source revision corresponding to the compiler that produced the error.

The token-based audit covers named failure statuses in returns, branch results,
assignments and cleanup calls. It rejects duplicate IDs/names and incomplete
helper calls. `--write` annotates bare terminal statuses and repairs duplicates
after their first occurrence. A new helper call may use site `0` and name
`"auto"` for assignment. `OUTPUT_FULL` always requires an explicit `fail-output`
call with sizes, so it is never automatically classified as retryable.
Both hybrid toolchain build workflows run the audit and its tests before building.

## Verification

Run the audit and `python -m unittest discover -s tools/codegen -p test_codegen_sites.py`.
Compile and run these with a verified hybrid compiler:

- `tools/self_hosting/tests/codegen-diagnostics-test.reds`
- `tools/self_hosting/tests/codegen-bridge-diagnostics-test.red`
- `tools/self_hosting/tests/x64-encoder-reds-test.reds`
- `tools/self_hosting/tests/arm64-encoder-reds-test.reds`

The diagnostic tests exercise both native backends on the host, without running
ARM64 machine code. Changes to the compiler must also pass bootstrap
self-compilation and the Red/System regression suite.

Verified for this change from `hybrid-compiler202.exe` through
`build/self-hosting/codegen-diagnostics/compiler4.exe`: the final two generations
self-compile to 6,493,184-byte compiler images. The final compiler passes 10,593
Red/System tests, 12,680 assertions, with no failures or compile failures, and
the four focused tests above pass. The site audit covers 1,765 sites, with all
seven audit tests passing.

For both final generations, `float-test`, `atomic-test`, and `exceptions-test`
produce the same binaries as 202 on Windows-X86-64, Linux-X86-64, Linux-ARM64,
and Darwin-ARM64. PE timestamp and checksum fields are excluded; ELF and Mach-O
comparisons are exact. Each comparison uses the same output path. These are
cross-compilation checks; runtime regression tests were run on Windows.
