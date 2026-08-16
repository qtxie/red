Red/System [
	Title: "Hybrid compiler Windows x64 encoder tests"
]

#include %../../../system/codegen/x64-encoder.reds

expected-void: #{554889E56A006A0068000000006A00C9C3}
expected-void-entry: #{554889E56A006A0068000000006A0031C94883EC20FF150000000031C0C9C3}
expected-i32: #{554889E56A006A0068000000006A00B807000000C9C3}
expected-i32-entry: #{554889E56A006A0068000000006A00B9070000004883EC20FF150000000031C0C9C3}
expected-call: #{554889E56A006A0068000000006A00E810000000C9C3}
expected-call-back: #{554889E56A006A0068000000006A00E8D6FFFFFFC9C3}
expected-call-entry: #{554889E56A006A0068000000006A00E81000000089C14883EC20FF150000000031C0C9C3}

failures: 0
code: allocate x64-encoder/CALL_ENTRY_SIZE
if null? code [quit 1]

size: x64-encoder/encode code x64-encoder/VOID_SIZE false x64-encoder/VOID 0 0
if size <> x64-encoder/VOID_SIZE [failures: failures + 1]
if (compare-memory code (as byte-ptr! expected-void) size) <> 0 [
	failures: failures + 1
]

size: x64-encoder/encode code x64-encoder/VOID_ENTRY_SIZE true x64-encoder/VOID 0 0
if size <> x64-encoder/VOID_ENTRY_SIZE [failures: failures + 1]
if (compare-memory code (as byte-ptr! expected-void-entry) size) <> 0 [
	failures: failures + 1
]
if x64-encoder/VOID_EXIT_REF <> 23 [failures: failures + 1]

size: x64-encoder/encode code x64-encoder/I32_SIZE false x64-encoder/I32_LITERAL 7 0
if size <> x64-encoder/I32_SIZE [failures: failures + 1]
if (compare-memory code (as byte-ptr! expected-i32) size) <> 0 [
	failures: failures + 1
]

size: x64-encoder/encode code x64-encoder/I32_ENTRY_SIZE true x64-encoder/I32_LITERAL 7 0
if size <> x64-encoder/I32_ENTRY_SIZE [failures: failures + 1]
if (compare-memory code (as byte-ptr! expected-i32-entry) size) <> 0 [
	failures: failures + 1
]
if x64-encoder/I32_EXIT_REF <> 26 [failures: failures + 1]

size: x64-encoder/encode code x64-encoder/CALL_SIZE false x64-encoder/I32_CALL 16 0
if size <> x64-encoder/CALL_SIZE [failures: failures + 1]
if (compare-memory code (as byte-ptr! expected-call) size) <> 0 [
	failures: failures + 1
]

size: x64-encoder/encode code x64-encoder/CALL_ENTRY_SIZE true x64-encoder/I32_CALL 16 0
if size <> x64-encoder/CALL_ENTRY_SIZE [failures: failures + 1]
if (compare-memory code (as byte-ptr! expected-call-entry) size) <> 0 [
	failures: failures + 1
]
if x64-encoder/CALL_EXIT_REF <> 28 [failures: failures + 1]
if x64-encoder/CALL_NEXT <> 20 [failures: failures + 1]

size: x64-encoder/encode code x64-encoder/CALL_SIZE false x64-encoder/I32_CALL -42 0
if size <> x64-encoder/CALL_SIZE [failures: failures + 1]
if (compare-memory code (as byte-ptr! expected-call-back) size) <> 0 [
	failures: failures + 1
]

size: x64-encoder/encode code (x64-encoder/VOID_SIZE - 1)
	false x64-encoder/VOID 0 0
if size <> -1 [failures: failures + 1]

free code
either failures = 0 [
	print ["PASS: direct Windows x64 encoder" lf]
][
	print ["FAIL: direct Windows x64 encoder failures=" failures lf]
]
quit failures
