Red/System [Title: "Hybrid codegen diagnostic contracts"]

#include %../../../system/codegen/x64-codegen.reds
#include %../../../system/codegen/arm64-codegen.reds

failures: 0
check: func [condition [logic!] message [c-string!]][
	unless condition [print ["FAIL: " message lf] failures: failures + 1]
]

ir: allocate 256
output: allocate 4096
set-memory ir as byte! 0 256
header: as rsir-header! ir
header/module-kind: 1
header/function-count: 1
header/instruction-count: 1
fn: as rsir-function! (ir + 44)
fn/name-size: 2
fn/instruction-count: 1
instruction: as rsir-instruction! (ir + 80)
instruction/op: 11
ir/97: as byte! 66h
ir/98: as byte! 6Eh

result: x64-codegen/generate ir 98 output 4096 1 0
check result > 0 "x64 valid module"
check codegen-diag/status = 0 "x64 success has no diagnostic"
result: x64-codegen/generate ir 98 output 1 1 0
check result = x64-codegen/OUTPUT_FULL "x64 capacity is retryable"
check all [codegen-diag/expected > 1 codegen-diag/actual = 1] "x64 required capacity"
result: x64-codegen/generate ir 98 output 4096 1 0
check all [result > 0 codegen-diag/status = 0] "x64 retry resets diagnostic"

result: arm64-codegen/generate ir 98 output 4096 3 0
check result > 0 "ARM64 valid module"
result: arm64-codegen/generate ir 98 output 1 3 0
check result = arm64-codegen/OUTPUT_FULL "ARM64 capacity is retryable"
required: codegen-diag/expected
check all [required > 1 codegen-diag/actual = 1] "ARM64 exact required capacity"
result: arm64-codegen/generate ir 98 output required 3 0
check all [result = required codegen-diag/status = 0] "ARM64 exact-size retry succeeds"

result: arm64-codegen/generate ir 43 output 4096 3 0
check result = arm64-codegen/INVALID_IR "truncated IR rejected"
check codegen-diag/site-file = codegen-diag/FILE_READER "reader origin preserved"
origin: codegen-diag/site
result: arm64-codegen/fail-code result 999 "outer-caller"
check all [result = arm64-codegen/INVALID_IR codegen-diag/site = origin] "propagation preserves first failure"

result: x64-codegen/generate ir 98 output 4096 3 0
check result = x64-codegen/UNSUPPORTED "unsupported x64 ABI"
check all [codegen-diag/site-file = codegen-diag/FILE_X64
	codegen-diag/function-index = 0 codegen-diag/instruction-index = 0] "ABI rejection resets old context"

instruction/op: 6
result: arm64-codegen/generate ir 98 output 4096 3 0
check result = arm64-codegen/INVALID_IR "missing member operand is invalid IR"
check all [codegen-diag/function-index = 1 codegen-diag/instruction-index = 1
	codegen-diag/op = 6 codegen-diag/function-name-size = 2] "ARM64 failure identifies its instruction and function"

header/line-record-count: 1
header/file-count: 1
line: as rsir-line-record! (ir + 96)
line/function-id: 1
line/instruction-index: 1
line/line: 42
line/file-id: 1
file: as rsir-file-entry! (ir + 112)
file/name-offset: 2
file/name-size: 8
copy-memory (ir + 120) as byte-ptr! "fnunit.red" 10
result: arm64-codegen/generate ir 130 output 4096 3 0
check all [result = arm64-codegen/INVALID_IR codegen-diag/source-line = 42
	codegen-diag/source-name-size = 8] "sparse source location is captured"
codegen-diag/report
header/line-record-count: 0
header/file-count: 0
ir/97: as byte! 66h
ir/98: as byte! 6Eh
instruction/op: 11

codegen-diag/reset
codegen-diag/mark-function 7
codegen-diag/mark-instruction 3 as int-ptr! instruction
result: arm64-codegen/fail-mismatch 16 20 998 "test/emission-size-mismatch"
codegen-diag/mark-function 9
instruction/op: 6
check all [result = arm64-codegen/INTERNAL_ERROR codegen-diag/function-index = 7
	codegen-diag/instruction-index = 3 codegen-diag/op = 11
	codegen-diag/expected = 16 codegen-diag/actual = 20] "failure context is a snapshot"

codegen-diag/reset
references: declare arm64-reference-state!
references/references: null
references/counts: as int-ptr! output
references/counts/1: 2147483647
result: arm64-codegen/record-reference 1 0 references
check all [result = arm64-codegen/RESOURCE_LIMIT codegen-diag/site > 0] "reference-count overflow is not retryable capacity"
codegen-diag/reset
result: x64-codegen/fail-memory 996 "test/allocation"
check result = x64-codegen/OUT_OF_MEMORY "allocation failure is not retryable capacity"

codegen-diag/reset
result: arm64-encoder/move-register output 0 9 10 8
check result = arm64-encoder/BUFFER_FULL "encoder capacity status"
result: arm64-codegen/fail-code result 995 "test/function-slice"
check result = arm64-codegen/INTERNAL_ERROR "measured function shortage is internal"
codegen-diag/reset
result: arm64-encoder/move-register output 4096 99 10 8
check result = -1 "encoder operand rejection"
check codegen-diag/status = 0 "encoding probe does not record terminal failure"
result: arm64-codegen/fail-code result 994 "test/invalid-register"
check result = arm64-codegen/INTERNAL_ERROR "committed operand rejection is internal"

free output
free ir
print ["codegen diagnostics: " failures " failures" lf]
quit failures
