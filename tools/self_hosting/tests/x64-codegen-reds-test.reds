Red/System [
	Title: "Direct compact RSIR to Windows x64 codegen tests"
]

#include %../../../system/codegen/x64-codegen.reds

failures: 0
ir: allocate 82
output: allocate 256
header: declare codegen-header!
reference: as int-ptr! 0
expected-code: #{554889E56A006A0068000000006A00B9070000004883EC20FF150000000031C0C9C3}
if any [null? ir null? output][quit 1]

put: func [data [byte-ptr!] offset value [integer!]][
	x64-encoder/write-i32 (data + offset) value
]

; GLUE module containing fn: func [return: [integer!]][7]
put ir 0 3
put ir 4 1
put ir 8 0
put ir 12 1
put ir 16 2
put ir 20 0
put ir 24 2
put ir 28 -5
put ir 32 0
put ir 36 0
put ir 40 0
put ir 44 2
put ir 48 1
put ir 52 1
put ir 56 0
put ir 60 7
put ir 64 3
put ir 68 0
put ir 72 1
put ir 76 0
ir/81: as byte! 66h
ir/82: as byte! 6Eh

size: x64-codegen/generate ir 82 output 256 0
if size <> 196 [failures: failures + 1]
if failures = 0 [
	header: as codegen-header! output
	if header/size <> 196 [failures: failures + 1]
	if header/module-kind <> 3 [failures: failures + 1]
	if header/entry-function <> 1 [failures: failures + 1]
	if header/function-count <> 1 [failures: failures + 1]
	if header/import-count <> 1 [failures: failures + 1]
	if header/reference-count <> 1 [failures: failures + 1]
	if header/names-size <> 25 [failures: failures + 1]
	if header/code-offset <> 144 [failures: failures + 1]
	if header/code-size <> 34 [failures: failures + 1]
	if header/data-size <> 16 [failures: failures + 1]
	if (compare-memory (output + 104)
		(as byte-ptr! "fnkernel32.dllExitProcess") 25) <> 0 [
		failures: failures + 1
	]
	if (compare-memory (output + 144) (as byte-ptr! expected-code) 34) <> 0 [
		failures: failures + 1
	]
	reference: as int-ptr! (output + 100)
	if reference/1 <> 26 [failures: failures + 1]
]

if (x64-codegen/generate ir 81 output 256 0) <> x64-codegen/INVALID_IR [
	failures: failures + 1
]
if (x64-codegen/generate ir 82 output 256 2) <> x64-codegen/UNSUPPORTED [
	failures: failures + 1
]
if (x64-codegen/generate ir 82 output 64 0) <> x64-codegen/OUTPUT_FULL [
	failures: failures + 1
]
put ir 32 512
if (x64-codegen/generate ir 82 output 256 0) <> x64-codegen/INVALID_IR [
	failures: failures + 1
]

free ir
free output
either failures = 0 [
	print ["PASS: compact RSIR to Windows x64 codegen" lf]
][
	print ["FAIL: compact x64 codegen failures=" failures lf]
]
quit failures
