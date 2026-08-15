Red/System [
	Title: "Hybrid compiler Windows x64 encoder tests"
]

#include %../../../system/codegen/x64-encoder.reds

expected: #{554889E56A006A0068000000006A00C9C3}
expected-entry: #{554889E56A006A0068000000006A0031C94883EC20FF150000000031C0C9C3}
expected-i32: #{554889E56A006A0068000000006A00B807000000C9C3}
expected-i32-entry: #{554889E56A006A0068000000006A00B9070000004883EC20FF150000000031C0C9C3}
failures: 0
patch: as byte-ptr! 0

arena: declare wire-arena!
wire-arena/reset arena
status: wire-arena/init arena wire-x64-encoder/EMPTY_VOID_FUNCTION_SIZE
	wire-x64-encoder/EMPTY_VOID_FUNCTION_SIZE
if status <> wire-arena/ERROR_SUCCESS [failures: failures + 1]
if failures = 0 [
	status: wire-x64-encoder/encode-empty-void-function arena
	if status <> wire-x64-encoder/ERROR_SUCCESS [failures: failures + 1]
	if arena/size <> wire-x64-encoder/EMPTY_VOID_FUNCTION_SIZE [
		failures: failures + 1
	]
	if (compare-memory arena/data (as byte-ptr! expected) arena/size) <> 0 [
		failures: failures + 1
	]
	patch: arena/data + wire-x64-encoder/BITMAP_PATCH_OFFSET
	if patch/1 <> as byte! 0 [failures: failures + 1]
]
wire-arena/release arena

wire-arena/reset arena
status: wire-arena/init arena wire-x64-encoder/I32_FUNCTION_SIZE
	wire-x64-encoder/I32_FUNCTION_SIZE
if status <> wire-arena/ERROR_SUCCESS [failures: failures + 1]
if failures = 0 [
	status: wire-x64-encoder/encode-i32-function arena 7
	if status <> wire-x64-encoder/ERROR_SUCCESS [failures: failures + 1]
	if arena/size <> wire-x64-encoder/I32_FUNCTION_SIZE [failures: failures + 1]
	if (compare-memory arena/data (as byte-ptr! expected-i32) arena/size) <> 0 [
		failures: failures + 1
	]
]
wire-arena/release arena

wire-arena/reset arena
status: wire-arena/init arena wire-x64-encoder/I32_ENTRY_FUNCTION_SIZE
	wire-x64-encoder/I32_ENTRY_FUNCTION_SIZE
if status <> wire-arena/ERROR_SUCCESS [failures: failures + 1]
if failures = 0 [
	status: wire-x64-encoder/encode-i32-entry arena 7
	if status <> wire-x64-encoder/ERROR_SUCCESS [failures: failures + 1]
	if arena/size <> wire-x64-encoder/I32_ENTRY_FUNCTION_SIZE [failures: failures + 1]
	if (compare-memory arena/data (as byte-ptr! expected-i32-entry) arena/size) <> 0 [
		failures: failures + 1
	]
	if wire-x64-encoder/I32_ENTRY_RELOCATION_OFFSET <> 26 [failures: failures + 1]
]
wire-arena/release arena

wire-arena/reset arena
status: wire-arena/init arena wire-x64-encoder/EMPTY_VOID_ENTRY_FUNCTION_SIZE
	wire-x64-encoder/EMPTY_VOID_ENTRY_FUNCTION_SIZE
if status <> wire-arena/ERROR_SUCCESS [failures: failures + 1]
if failures = 0 [
	status: wire-x64-encoder/encode-empty-void-entry arena
	if status <> wire-x64-encoder/ERROR_SUCCESS [failures: failures + 1]
	if arena/size <> wire-x64-encoder/EMPTY_VOID_ENTRY_FUNCTION_SIZE [
		failures: failures + 1
	]
	if (compare-memory arena/data (as byte-ptr! expected-entry) arena/size) <> 0 [
		failures: failures + 1
	]
	if wire-x64-encoder/EMPTY_VOID_ENTRY_RELOCATION_OFFSET <> 23 [
		failures: failures + 1
	]
]
wire-arena/release arena

wire-arena/reset arena
status: wire-arena/init arena
	(wire-x64-encoder/EMPTY_VOID_FUNCTION_SIZE - 1)
	(wire-x64-encoder/EMPTY_VOID_FUNCTION_SIZE - 1)
if status <> wire-arena/ERROR_SUCCESS [failures: failures + 1]
if failures = 0 [
	status: wire-x64-encoder/encode-empty-void-function arena
	if status <> wire-arena/ERROR_LIMIT [failures: failures + 1]
	if arena/size <> 0 [failures: failures + 1]
]
wire-arena/release arena

either failures = 0 [
	print ["PASS: Windows x64 void and i32 function encoder" lf]
][
	print ["FAIL: Windows x64 encoder failures=" failures lf]
]
quit failures
