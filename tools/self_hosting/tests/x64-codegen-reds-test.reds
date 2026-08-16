Red/System [
	Title: "Direct compact RSIR to Windows x64 codegen tests"
]

#include %../../../system/codegen/x64-codegen.reds

failures: 0
ir: allocate 90
output: allocate 512
header: declare codegen-header!
first-import: declare codegen-import!
second-import: declare codegen-import!
image-global: declare codegen-global!
reference: as int-ptr! 0
global-value: as int-ptr! 0
expected-code: #{554889E56A006A0068000000006A00B9070000004883EC20FF150000000031C0C9C3}
import-code: #{554889E56A006A0068000000006A004883EC20B907000000FF150000000089C1FF150000000031C0C9C3}
global-code: #{554889E56A006A0068000000006A008B0500000000C9C3}
if any [null? ir null? output][quit 1]

put: func [data [byte-ptr!] offset value [integer!]][
	x64-encoder/write-i32 (data + offset) value
]

; GLUE module containing fn: func [return: [integer!]][7]
put ir 0 3
put ir 4 1
put ir 8 0
put ir 12 0
put ir 16 1
put ir 20 2
put ir 24 0
put ir 28 0
put ir 32 2
put ir 36 -5
put ir 40 0
put ir 44 0
put ir 48 0
put ir 52 2
put ir 56 1
put ir 60 1
put ir 64 0
put ir 68 7
put ir 72 3
put ir 76 0
put ir 80 1
put ir 84 0
ir/89: as byte! 66h
ir/90: as byte! 6Eh

size: x64-codegen/generate ir 90 output 256 0
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
	if header/global-count <> 0 [failures: failures + 1]
	if (compare-memory (output + 108)
		(as byte-ptr! "fnkernel32.dllExitProcess") 25) <> 0 [
		failures: failures + 1
	]
	if (compare-memory (output + 144) (as byte-ptr! expected-code) 34) <> 0 [
		failures: failures + 1
	]
	reference: as int-ptr! (output + 104)
	if reference/1 <> 26 [failures: failures + 1]
]

if (x64-codegen/generate ir 89 output 256 0) <> x64-codegen/INVALID_IR [
	failures: failures + 1
]
if (x64-codegen/generate ir 90 output 256 2) <> x64-codegen/UNSUPPORTED [
	failures: failures + 1
]
if (x64-codegen/generate ir 90 output 64 0) <> x64-codegen/OUTPUT_FULL [
	failures: failures + 1
]
put ir 40 512
if (x64-codegen/generate ir 90 output 256 0) <> x64-codegen/INVALID_IR [
	failures: failures + 1
]

; GLUE module containing an imported i32 call with one literal argument.
import-ir: allocate 168
if null? import-ir [quit 1]
put import-ir 0 3
put import-ir 4 1
put import-ir 8 0
put import-ir 12 1
put import-ir 16 1
put import-ir 20 3
put import-ir 24 0
put import-ir 28 0
put import-ir 32 11
put import-ir 36 11
put import-ir 40 11
put import-ir 44 -5
put import-ir 48 2
put import-ir 52 0
put import-ir 56 1
put import-ir 60 22
put import-ir 64 2
put import-ir 68 -5
put import-ir 72 0
put import-ir 76 1
put import-ir 80 0
put import-ir 84 3
put import-ir 88 -5
put import-ir 92 0
put import-ir 96 1
put import-ir 100 1
put import-ir 104 0
put import-ir 108 7
put import-ir 112 4
put import-ir 116 2
put import-ir 120 -1
put import-ir 124 1
put import-ir 128 3
put import-ir 132 0
put import-ir 136 2
put import-ir 140 0
copy-memory (import-ir + 144) (as byte-ptr! "fixture.dllnative-callfn") 24

size: x64-codegen/generate import-ir 168 output 512 0
if size <> 252 [failures: failures + 1]
if size = 252 [
	header: as codegen-header! output
	if header/import-count <> 2 [failures: failures + 1]
	if header/reference-count <> 2 [failures: failures + 1]
	if header/names-size <> 47 [failures: failures + 1]
	if header/code-offset <> 192 [failures: failures + 1]
	if header/code-size <> 42 [failures: failures + 1]
	first-import: as codegen-import! (output + 80)
	second-import: as codegen-import! (output + 104)
	if any [
		first-import/library <> 2
		first-import/library-size <> 11
		first-import/external <> 13
		first-import/external-size <> 11
		first-import/first-reference <> 1
		first-import/reference-count <> 1
		second-import/library <> 24
		second-import/library-size <> 12
		second-import/external <> 36
		second-import/external-size <> 11
		second-import/first-reference <> 2
		second-import/reference-count <> 1
	][failures: failures + 1]
	reference: as int-ptr! (output + 128)
	if reference/1 <> 26 [failures: failures + 1]
	if reference/2 <> 34 [failures: failures + 1]
	if (compare-memory (output + 136)
		(as byte-ptr! "fnfixture.dllnative-callkernel32.dllExitProcess") 47) <> 0 [
		failures: failures + 1
	]
	if (compare-memory (output + 192) (as byte-ptr! import-code) 42) <> 0 [
		failures: failures + 1
	]
]

; USER module containing answer: 42 and fn: func [return: [integer!]][answer]
global-ir: allocate 116
if null? global-ir [quit 1]
put global-ir 0 1
put global-ir 4 0
put global-ir 8 0
put global-ir 12 0
put global-ir 16 1
put global-ir 20 2
put global-ir 24 1
put global-ir 28 0
put global-ir 32 6
put global-ir 36 -5
put global-ir 40 42
put global-ir 44 0
put global-ir 48 6
put global-ir 52 2
put global-ir 56 -5
put global-ir 60 0
put global-ir 64 0
put global-ir 68 0
put global-ir 72 2
put global-ir 76 6
put global-ir 80 1
put global-ir 84 1
put global-ir 88 0
put global-ir 92 3
put global-ir 96 0
put global-ir 100 1
put global-ir 104 0
copy-memory (global-ir + 108) (as byte-ptr! "answerfn") 8

size: x64-codegen/generate global-ir 116 output 512 0
if size <> 172 [failures: failures + 1]
if size = 172 [
	header: as codegen-header! output
	if any [
		header/global-count <> 1
		header/names-size <> 8
		header/code-offset <> 128
		header/code-size <> 23
		header/data-size <> 20
	][failures: failures + 1]
	image-global: as codegen-global! (output + 80)
	if any [
		image-global/name <> 2
		image-global/name-size <> 6
		image-global/data-offset <> 16
		image-global/data-size <> 4
		image-global/first-reference <> 1
		image-global/reference-count <> 1
	][failures: failures + 1]
	reference: as int-ptr! (output + 104)
	if reference/1 <> 17 [failures: failures + 1]
	if (compare-memory (output + 108) (as byte-ptr! "fnanswer") 8) <> 0 [
		failures: failures + 1
	]
	if (compare-memory (output + 128) (as byte-ptr! global-code) 23) <> 0 [
		failures: failures + 1
	]
	global-value: as int-ptr! (output + 168)
	if global-value/1 <> 42 [failures: failures + 1]
]
put global-ir 36 0
if (x64-codegen/generate global-ir 116 output 512 0) <> x64-codegen/INVALID_IR [
	failures: failures + 1
]
put global-ir 36 -5
put global-ir 84 2
if (x64-codegen/generate global-ir 116 output 512 0) <> x64-codegen/INVALID_IR [
	failures: failures + 1
]

free ir
free import-ir
free global-ir
free output
either failures = 0 [
	print ["PASS: compact RSIR to Windows x64 codegen" lf]
][
	print ["FAIL: compact x64 codegen failures=" failures lf]
]
quit failures
