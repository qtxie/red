Red/System [
	Title: "Typed postfix RSIR to Windows x64 codegen tests"
]

#include %../../../system/codegen/x64-codegen.reds

#import [
	"kernel32.dll" stdcall [
		VirtualAlloc: "VirtualAlloc" [
			address [byte-ptr!]
			size [integer!]
			allocation [integer!]
			protection [integer!]
			return: [byte-ptr!]
		]
		VirtualFree: "VirtualFree" [
			address [byte-ptr!]
			size [integer!]
			free-type [integer!]
			return: [logic!]
		]
	]
]

selection-entry!: alias function! [return: [integer!]]

put: func [data [byte-ptr!] offset value [integer!]][
	x64-encoder/write-i32 (data + offset) value
]

put-instruction: func [
	data [byte-ptr!]
	offset op a b c [integer!]
][
	put data offset op
	put data (offset + 4) a
	put data (offset + 8) b
	put data (offset + 12) c
]

run-selection: func [
	code [byte-ptr!]
	return: [integer!]
	/local entry [selection-entry!]
][
	entry: as selection-entry! code
	entry
]

execute-selection?: func [
	image [byte-ptr!]
	expected [integer!]
	return: [logic!]
	/local header [codegen-header!] fn [codegen-function!]
		code [byte-ptr!] result [integer!]
][
	header: as codegen-header! image
	fn: as codegen-function! (image + x64-codegen/IMAGE_HEADER_SIZE)
	code: VirtualAlloc (as byte-ptr! 0) 4096 3000h 40h
	if null? code [return false]
	copy-memory code (image + header/code-offset + fn/code-offset) fn/code-size
	result: run-selection code
	VirtualFree code 0 8000h
	result = expected
]

failures: 0
output: allocate 1024
void-ir: allocate 128
local-ir: allocate 256
pointer-ir: allocate 128
arithmetic-ir: allocate 256
branch-ir: allocate 256
merge-ir: allocate 256
selection-ir: allocate 256
header: declare codegen-header!
fn: declare codegen-function!
if any [
	null? output null? void-ir null? local-ir null? pointer-ir null? arithmetic-ir
	null? branch-ir null? merge-ir
	null? selection-ir
][quit 1]

; USER module: fn: func [][]
put void-ir 0 1
put void-ir 4 0
put void-ir 8 0
put void-ir 12 0
put void-ir 16 1
put void-ir 20 1
put void-ir 24 0
put void-ir 28 0

put void-ir 32 0
put void-ir 36 2
put void-ir 40 0
put void-ir 44 0
put void-ir 48 0
put void-ir 52 0
put void-ir 56 0
put void-ir 60 0
put void-ir 64 1
put-instruction void-ir 68 11 0 0 0
void-ir/85: as byte! 66h
void-ir/86: as byte! 6Eh

size: x64-codegen/generate void-ir 86 output 1024 0
if size <> 132 [failures: failures + 1]
if size > 0 [
	header: as codegen-header! output
	fn: as codegen-function! (output + 44)
	if any [
		header/size <> size
		header/module-kind <> 1
		header/function-count <> 1
		header/import-count <> 0
		header/code-offset <> 96
		header/code-size <> 17
		fn/frame-size <> x64-encoder/BASE_FRAME_SIZE
		fn/code-size <> 17
	][failures: failures + 1]
]

if (x64-codegen/generate void-ir 85 output 1024 0) <> x64-codegen/INVALID_IR [
	failures: failures + 1
]
if (x64-codegen/generate void-ir 86 output 64 0) <> x64-codegen/OUTPUT_FULL [
	failures: failures + 1
]
if (x64-codegen/generate void-ir 86 output 1024 2) <> x64-codegen/UNSUPPORTED [
	failures: failures + 1
]

; fn: func [return: [integer!] /local value][value: 7 value]
put local-ir 0 1
put local-ir 4 0
put local-ir 8 0
put local-ir 12 0
put local-ir 16 1
put local-ir 20 7
put local-ir 24 0
put local-ir 28 0

put local-ir 32 0
put local-ir 36 2
put local-ir 40 -5
put local-ir 44 0
put local-ir 48 0
put local-ir 52 0
put local-ir 56 0
put local-ir 60 1
put local-ir 64 7

put local-ir 68 -5
put local-ir 72 0
put-instruction local-ir 76 3 1 1 0
put-instruction local-ir 92 1 -5 7 0
put-instruction local-ir 108 5 0 0 0
put-instruction local-ir 124 12 0 0 0
put-instruction local-ir 140 3 1 1 0
put-instruction local-ir 156 4 0 0 0
put-instruction local-ir 172 11 -5 0 0
local-ir/189: as byte! 66h
local-ir/190: as byte! 6Eh

size: x64-codegen/generate local-ir 190 output 1024 0
if size <= 0 [
	failures: failures + 1
]
if size > 0 [
	header: as codegen-header! output
	fn: as codegen-function! (output + 44)
	if any [
		header/code-size <= 17
		fn/frame-size <> 64
		fn/code-size <> header/code-size
	][failures: failures + 1]
]

; first-local and local-count describe one contiguous function storage slice.
put local-ir 56 1
if (x64-codegen/generate local-ir 190 output 1024 0) <> x64-codegen/INVALID_IR [
	failures: failures + 1
]
put local-ir 56 0
put local-ir 68 0
if (x64-codegen/generate local-ir 190 output 1024 0) <> x64-codegen/INVALID_IR [
	failures: failures + 1
]
put local-ir 68 -5

; Unused pointer node: logical pointee information must be accepted without
; changing code generated for the same function.
put pointer-ir 0 1
put pointer-ir 4 0
put pointer-ir 8 1
put pointer-ir 12 0
put pointer-ir 16 1
put pointer-ir 20 1
put pointer-ir 24 0
put pointer-ir 28 0
put pointer-ir 32 -6
put pointer-ir 36 -5
put pointer-ir 40 0
put pointer-ir 44 0
put pointer-ir 48 0
put pointer-ir 52 0
put pointer-ir 56 2
put pointer-ir 60 0
put pointer-ir 64 0
put pointer-ir 68 0
put pointer-ir 72 0
put pointer-ir 76 0
put pointer-ir 80 0
put pointer-ir 84 1
put-instruction pointer-ir 88 11 0 0 0
pointer-ir/105: as byte! 66h
pointer-ir/106: as byte! 6Eh

size: x64-codegen/generate pointer-ir 106 output 1024 0
if size <> 132 [failures: failures + 1]
put pointer-ir 36 0
if (x64-codegen/generate pointer-ir 106 output 1024 0) <> x64-codegen/INVALID_IR [
	failures: failures + 1
]

; fn: func [return: [integer!]][1 + 2 * 3]
put arithmetic-ir 0 1
put arithmetic-ir 4 0
put arithmetic-ir 8 0
put arithmetic-ir 12 0
put arithmetic-ir 16 1
put arithmetic-ir 20 6
put arithmetic-ir 24 0
put arithmetic-ir 28 0
put arithmetic-ir 32 0
put arithmetic-ir 36 2
put arithmetic-ir 40 -5
put arithmetic-ir 44 0
put arithmetic-ir 48 0
put arithmetic-ir 52 0
put arithmetic-ir 56 0
put arithmetic-ir 60 0
put arithmetic-ir 64 6
put-instruction arithmetic-ir 68 1 -5 1 0
put-instruction arithmetic-ir 84 1 -5 2 0
put-instruction arithmetic-ir 100 15 1 0 0
put-instruction arithmetic-ir 116 1 -5 3 0
put-instruction arithmetic-ir 132 15 3 0 0
put-instruction arithmetic-ir 148 11 -5 0 0
arithmetic-ir/165: as byte! 66h
arithmetic-ir/166: as byte! 6Eh

size: x64-codegen/generate arithmetic-ir 166 output 1024 0
if size <= 0 [failures: failures + 1]
if size > 0 [
	fn: as codegen-function! (output + 44)
	if any [fn/frame-size <> 48 fn/code-size <= 17][failures: failures + 1]
]
put arithmetic-ir 88 -11
if (x64-codegen/generate arithmetic-ir 166 output 1024 0) <> x64-codegen/INVALID_IR [
	failures: failures + 1
]
put arithmetic-ir 88 -5
put arithmetic-ir 104 19
if (x64-codegen/generate arithmetic-ir 166 output 1024 0) <> x64-codegen/INVALID_IR [
	failures: failures + 1
]

; fn: func [return: [integer!]][either true [return 7][return 9]]
put branch-ir 0 1
put branch-ir 4 0
put branch-ir 8 0
put branch-ir 12 0
put branch-ir 16 1
put branch-ir 20 6
put branch-ir 24 0
put branch-ir 28 0
put branch-ir 32 0
put branch-ir 36 2
put branch-ir 40 -5
put branch-ir 44 0
put branch-ir 48 0
put branch-ir 52 0
put branch-ir 56 0
put branch-ir 60 0
put branch-ir 64 6
put-instruction branch-ir 68 1 -11 1 0
put-instruction branch-ir 84 17 5 0 0
put-instruction branch-ir 100 1 -5 7 0
put-instruction branch-ir 116 11 -5 0 0
put-instruction branch-ir 132 1 -5 9 0
put-instruction branch-ir 148 11 -5 0 0
branch-ir/165: as byte! 66h
branch-ir/166: as byte! 6Eh

size: x64-codegen/generate branch-ir 166 output 1024 0
if size <= 0 [failures: failures + 1]
put branch-ir 88 7
if (x64-codegen/generate branch-ir 166 output 1024 0) <> x64-codegen/INVALID_IR [
	failures: failures + 1
]
put branch-ir 88 5
put branch-ir 92 2
if (x64-codegen/generate branch-ir 166 output 1024 0) <> x64-codegen/INVALID_IR [
	failures: failures + 1
]
put branch-ir 92 0
put branch-ir 72 -5
if (x64-codegen/generate branch-ir 166 output 1024 0) <> x64-codegen/INVALID_IR [
	failures: failures + 1
]
put branch-ir 72 -11
put branch-ir 88 4
if (x64-codegen/generate branch-ir 166 output 1024 0) <> x64-codegen/INVALID_IR [
	failures: failures + 1
]

; A typed stack merge accepts matching arm values and rejects equal-depth
; edges whose top values have different logical types.
put merge-ir 0 1
put merge-ir 4 0
put merge-ir 8 0
put merge-ir 12 0
put merge-ir 16 1
put merge-ir 20 7
put merge-ir 24 0
put merge-ir 28 0
put merge-ir 32 0
put merge-ir 36 2
put merge-ir 40 0
put merge-ir 44 0
put merge-ir 48 0
put merge-ir 52 0
put merge-ir 56 0
put merge-ir 60 0
put merge-ir 64 7
put-instruction merge-ir 68 1 -11 1 0
put-instruction merge-ir 84 17 5 0 0
put-instruction merge-ir 100 1 -5 7 0
put-instruction merge-ir 116 16 6 0 0
put-instruction merge-ir 132 1 -5 9 0
put-instruction merge-ir 148 12 0 0 0
put-instruction merge-ir 164 11 0 0 0
merge-ir/181: as byte! 66h
merge-ir/182: as byte! 6Eh

if (x64-codegen/generate merge-ir 182 output 1024 0) <= 0 [failures: failures + 1]
put merge-ir 136 -11
if (x64-codegen/generate merge-ir 182 output 1024 0) <> x64-codegen/INVALID_IR [
	failures: failures + 1
]

; A SWITCH consumes one typed selector and reaches every table/default target
; at the same stack depth. The trailing FAIL independently checks termination.
put selection-ir 0 1
put selection-ir 4 0
put selection-ir 8 0
put selection-ir 12 0
put selection-ir 16 1
put selection-ir 20 7
put selection-ir 24 0
put selection-ir 28 1
put selection-ir 32 0
put selection-ir 36 2
put selection-ir 40 -5
put selection-ir 44 0
put selection-ir 48 0
put selection-ir 52 0
put selection-ir 56 0
put selection-ir 60 0
put selection-ir 64 7
put selection-ir 68 2
put selection-ir 72 0
put selection-ir 76 5
put-instruction selection-ir 80 1 -5 2 0
put-instruction selection-ir 96 18 0 1 3
put-instruction selection-ir 112 1 -5 9 0
put-instruction selection-ir 128 11 -5 0 0
put-instruction selection-ir 144 1 -5 7 0
put-instruction selection-ir 160 11 -5 0 0
put-instruction selection-ir 176 19 101 0 0
selection-ir/193: as byte! 66h
selection-ir/194: as byte! 6Eh

if (x64-codegen/generate selection-ir 194 output 1024 0) <= 0 [
	failures: failures + 1
]
unless execute-selection? output 7 [failures: failures + 1]
put selection-ir 88 9
if (x64-codegen/generate selection-ir 194 output 1024 0) <= 0 [
	failures: failures + 1
]
unless execute-selection? output 9 [failures: failures + 1]
put selection-ir 88 2

put selection-ir 84 -7
if (x64-codegen/generate selection-ir 194 output 1024 0) <= 0 [
	failures: failures + 1
]
unless execute-selection? output 7 [failures: failures + 1]

put selection-ir 84 -2
put selection-ir 88 65
put selection-ir 68 65
if (x64-codegen/generate selection-ir 194 output 1024 0) <= 0 [
	failures: failures + 1
]
unless execute-selection? output 7 [failures: failures + 1]
put selection-ir 84 -5
put selection-ir 88 2
put selection-ir 68 2

put selection-ir 100 1
if (x64-codegen/generate selection-ir 194 output 1024 0) <> x64-codegen/INVALID_IR [
	failures: failures + 1
]
put selection-ir 100 0
put selection-ir 104 2
if (x64-codegen/generate selection-ir 194 output 1024 0) <> x64-codegen/INVALID_IR [
	failures: failures + 1
]
put selection-ir 104 1
put selection-ir 76 0
if (x64-codegen/generate selection-ir 194 output 1024 0) <> x64-codegen/INVALID_IR [
	failures: failures + 1
]
put selection-ir 76 5
put selection-ir 180 0
if (x64-codegen/generate selection-ir 194 output 1024 0) <> x64-codegen/INVALID_IR [
	failures: failures + 1
]
put selection-ir 180 101

; Trimming the true edge and dropping the false value reconciles a
; value-less EITHER without emitting a native move.
put merge-ir 120 7
put merge-ir 124 1
if (x64-codegen/generate merge-ir 182 output 1024 0) <= 0 [failures: failures + 1]
put merge-ir 124 2
if (x64-codegen/generate merge-ir 182 output 1024 0) <> x64-codegen/INVALID_IR [
	failures: failures + 1
]

free output
free void-ir
free local-ir
free pointer-ir
free arithmetic-ir
free branch-ir
free merge-ir
free selection-ir
either failures = 0 [
	print ["PASS: typed postfix Windows x64 codegen" lf]
][
	print ["FAIL: typed postfix x64 codegen failures=" failures lf]
]
quit failures
