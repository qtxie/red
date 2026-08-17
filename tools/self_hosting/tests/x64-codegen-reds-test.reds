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

execute-first?: func [
	image [byte-ptr!]
	expected [integer!]
	return: [logic!]
	/local header [codegen-header!] fn [codegen-function!]
		code [byte-ptr!] result [integer!]
][
	header: as codegen-header! image
	fn: as codegen-function! (image + x64-codegen/IMAGE_HEADER_SIZE)
	if header/code-size > 4096 [return false]
	code: VirtualAlloc (as byte-ptr! 0) 4096 3000h 40h
	if null? code [return false]
	copy-memory code (image + header/code-offset) header/code-size
	result: run-selection (code + fn/code-offset)
	VirtualFree code 0 8000h
	result = expected
]

failures: 0
output: allocate 1024
void-ir: allocate 128
local-ir: allocate 256
pointer-ir: allocate 128
arithmetic-ir: allocate 256
aggregate-ir: allocate 512
abi-ir: allocate 1024
indirect-ir: allocate 320
null-function-ir: allocate 192
tagged-ir: allocate 384
array-ir: allocate 256
branch-ir: allocate 256
merge-ir: allocate 256
selection-ir: allocate 256
recursive-pointer-ir: allocate 160
recursive-value-ir: allocate 144
header: declare codegen-header!
fn: declare codegen-function!
image-global: declare codegen-global!
array-values: as int-ptr! 0
if any [
	null? output null? void-ir null? local-ir null? pointer-ir null? arithmetic-ir
	null? aggregate-ir null? abi-ir null? indirect-ir null? null-function-ir
	null? tagged-ir null? array-ir null? branch-ir
	null? merge-ir null? selection-ir null? recursive-pointer-ir null? recursive-value-ir
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
	fn: as codegen-function! (output + x64-codegen/IMAGE_HEADER_SIZE)
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
	fn: as codegen-function! (output + x64-codegen/IMAGE_HEADER_SIZE)
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
	fn: as codegen-function! (output + x64-codegen/IMAGE_HEADER_SIZE)
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

; Two inline pair values occupy their own storage. LOAD exposes the source
; address, SET copies its layout, and the assignment result remains the target.
put aggregate-ir 0 1
put aggregate-ir 4 0
put aggregate-ir 8 1
put aggregate-ir 12 0
put aggregate-ir 16 1
put aggregate-ir 20 21
put aggregate-ir 24 0
put aggregate-ir 28 0

put aggregate-ir 32 -2
put aggregate-ir 36 0
put aggregate-ir 40 0
put aggregate-ir 44 0
put aggregate-ir 48 2
put aggregate-ir 52 -5
put aggregate-ir 56 0
put aggregate-ir 60 -5
put aggregate-ir 64 0

put aggregate-ir 68 0
put aggregate-ir 72 2
put aggregate-ir 76 -5
put aggregate-ir 80 0
put aggregate-ir 84 0
put aggregate-ir 88 0
put aggregate-ir 92 0
put aggregate-ir 96 2
put aggregate-ir 100 21

put aggregate-ir 104 1
put aggregate-ir 108 1
put aggregate-ir 112 1
put aggregate-ir 116 1

put-instruction aggregate-ir 120 3 1 1 0
put-instruction aggregate-ir 136 6 0 0 0
put-instruction aggregate-ir 152 1 -5 17 0
put-instruction aggregate-ir 168 5 0 0 0
put-instruction aggregate-ir 184 12 0 0 0
put-instruction aggregate-ir 200 3 1 2 0
put-instruction aggregate-ir 216 3 1 1 0
put-instruction aggregate-ir 232 4 0 0 0
put-instruction aggregate-ir 248 5 0 0 0
put-instruction aggregate-ir 264 6 1 0 0
put-instruction aggregate-ir 280 1 -5 29 0
put-instruction aggregate-ir 296 5 0 0 0
put-instruction aggregate-ir 312 12 0 0 0
put-instruction aggregate-ir 328 3 1 2 0
put-instruction aggregate-ir 344 6 0 0 0
put-instruction aggregate-ir 360 4 0 0 0
put-instruction aggregate-ir 376 3 1 2 0
put-instruction aggregate-ir 392 6 1 0 0
put-instruction aggregate-ir 408 4 0 0 0
put-instruction aggregate-ir 424 15 1 0 0
put-instruction aggregate-ir 440 11 -5 0 0
aggregate-ir/457: as byte! 66h
aggregate-ir/458: as byte! 6Eh

size: x64-codegen/generate aggregate-ir 458 output 1024 0
if size <= 0 [failures: failures + 1]
if size > 0 [
	fn: as codegen-function! (output + x64-codegen/IMAGE_HEADER_SIZE)
	if fn/frame-size <> 64 [failures: failures + 1]
	unless execute-selection? output 46 [failures: failures + 1]
]

; A 12-byte struct is copied into caller-owned argument storage and returned
; through the hidden first pointer. The callee changes its copy to 70; adding
; the untouched caller value 7 proves both directions of value isolation.
put abi-ir 0 1
put abi-ir 4 0
put abi-ir 8 1
put abi-ir 12 0
put abi-ir 16 2
put abi-ir 20 33
put abi-ir 24 0
put abi-ir 28 0

put abi-ir 32 -2
put abi-ir 36 0
put abi-ir 40 0
put abi-ir 44 0
put abi-ir 48 3

put abi-ir 52 -5
put abi-ir 56 0
put abi-ir 60 -5
put abi-ir 64 0
put abi-ir 68 -5
put abi-ir 72 0

put abi-ir 76 0
put abi-ir 80 4
put abi-ir 84 -5
put abi-ir 88 0
put abi-ir 92 0
put abi-ir 96 0
put abi-ir 100 0
put abi-ir 104 1
put abi-ir 108 25

put abi-ir 112 4
put abi-ir 116 2
put abi-ir 120 1
put abi-ir 124 4
put abi-ir 128 1
put abi-ir 132 1
put abi-ir 136 2
put abi-ir 140 0
put abi-ir 144 8

put abi-ir 148 1
put abi-ir 152 1
put abi-ir 156 1
put abi-ir 160 1

put-instruction abi-ir 164 3 1 1 0
put-instruction abi-ir 180 6 0 0 0
put-instruction abi-ir 196 1 -5 7 0
put-instruction abi-ir 212 5 0 0 0
put-instruction abi-ir 228 12 0 0 0
put-instruction abi-ir 244 3 1 1 0
put-instruction abi-ir 260 6 1 0 0
put-instruction abi-ir 276 1 -5 8 0
put-instruction abi-ir 292 5 0 0 0
put-instruction abi-ir 308 12 0 0 0
put-instruction abi-ir 324 3 1 1 0
put-instruction abi-ir 340 6 2 0 0
put-instruction abi-ir 356 1 -5 9 0
put-instruction abi-ir 372 5 0 0 0
put-instruction abi-ir 388 12 0 0 0
put-instruction abi-ir 404 3 1 1 0
put-instruction abi-ir 420 4 0 0 0
put-instruction abi-ir 436 7 2 1 1
put-instruction abi-ir 452 6 0 0 0
put-instruction abi-ir 468 4 0 0 0
put-instruction abi-ir 484 3 1 1 0
put-instruction abi-ir 500 6 0 0 0
put-instruction abi-ir 516 4 0 0 0
put-instruction abi-ir 532 15 1 0 0
put-instruction abi-ir 548 11 -5 0 0

put-instruction abi-ir 564 3 1 1 0
put-instruction abi-ir 580 6 0 0 0
put-instruction abi-ir 596 1 -5 70 0
put-instruction abi-ir 612 5 0 0 0
put-instruction abi-ir 628 12 0 0 0
put-instruction abi-ir 644 3 1 1 0
put-instruction abi-ir 660 4 0 0 0
put-instruction abi-ir 676 11 1 0 0
abi-ir/693: as byte! 6Dh
abi-ir/694: as byte! 61h
abi-ir/695: as byte! 69h
abi-ir/696: as byte! 6Eh
abi-ir/697: as byte! 69h
abi-ir/698: as byte! 64h

size: x64-codegen/generate abi-ir 698 output 1024 0
if size <= 0 [failures: failures + 1]
if size > 0 [
	header: as codegen-header! output
	if header/function-count <> 2 [failures: failures + 1]
	unless execute-first? output 77 [failures: failures + 1]
]

; A function address is an ordinary typed value. The caller keeps it below
; one argument, CALL consumes both slots, and the callee returns 41 + 1.
put indirect-ir 0 1
put indirect-ir 4 0
put indirect-ir 8 1
put indirect-ir 12 0
put indirect-ir 16 2
put indirect-ir 20 10
put indirect-ir 24 0
put indirect-ir 28 0

put indirect-ir 32 -4
put indirect-ir 36 -5
put indirect-ir 40 0
put indirect-ir 44 0
put indirect-ir 48 1

put indirect-ir 52 -5
put indirect-ir 56 0

put indirect-ir 60 0
put indirect-ir 64 1
put indirect-ir 68 -5
put indirect-ir 72 0
put indirect-ir 76 0
put indirect-ir 80 0
put indirect-ir 84 0
put indirect-ir 88 0
put indirect-ir 92 5

put indirect-ir 96 1
put indirect-ir 100 1
put indirect-ir 104 -5
put indirect-ir 108 0
put indirect-ir 112 0
put indirect-ir 116 1
put indirect-ir 120 1
put indirect-ir 124 0
put indirect-ir 128 5

put indirect-ir 132 -5
put indirect-ir 136 0

put-instruction indirect-ir 140 3 4 2 1
put-instruction indirect-ir 156 20 1 0 0
put-instruction indirect-ir 172 1 -5 41 0
put-instruction indirect-ir 188 7 0 1 1
put-instruction indirect-ir 204 11 -5 0 0

put-instruction indirect-ir 220 3 1 1 0
put-instruction indirect-ir 236 4 0 0 0
put-instruction indirect-ir 252 1 -5 1 0
put-instruction indirect-ir 268 15 1 0 0
put-instruction indirect-ir 284 11 -5 0 0
indirect-ir/301: as byte! 6Dh
indirect-ir/302: as byte! 69h

size: x64-codegen/generate indirect-ir 302 output 1024 0
if size <= 0 [
	failures: failures + 1
]
if size > 0 [
	header: as codegen-header! output
	if header/function-count <> 2 [failures: failures + 1]
	unless execute-first? output 42 [failures: failures + 1]
]
put indirect-ir 200 -5
if (x64-codegen/generate indirect-ir 302 output 1024 0) <> x64-codegen/INVALID_IR [
	failures: failures + 1
]
put indirect-ir 200 1

; NULL is typeless until the frontend coerces it to a declared reference.
; The native core preserves the zero bits while changing only the stack type.
put null-function-ir 0 1
put null-function-ir 4 0
put null-function-ir 8 1
put null-function-ir 12 0
put null-function-ir 16 1
put null-function-ir 20 5
put null-function-ir 24 0
put null-function-ir 28 0

put null-function-ir 32 -4
put null-function-ir 36 -5
put null-function-ir 40 0
put null-function-ir 44 0
put null-function-ir 48 0

put null-function-ir 52 0
put null-function-ir 56 1
put null-function-ir 60 -11
put null-function-ir 64 0
put null-function-ir 68 0
put null-function-ir 72 0
put null-function-ir 76 0
put null-function-ir 80 0
put null-function-ir 84 5

put-instruction null-function-ir 88 1 -14 0 0
put-instruction null-function-ir 104 8 1 0 0
put-instruction null-function-ir 120 1 -14 0 0
put-instruction null-function-ir 136 15 13 0 0
put-instruction null-function-ir 152 11 -11 0 0
null-function-ir/169: as byte! 6Eh

size: x64-codegen/generate null-function-ir 169 output 1024 0
if size <= 0 [
	failures: failures + 1
]
if size > 0 [
	unless execute-selection? output 1 [failures: failures + 1]
]
put null-function-ir 108 -2
if (x64-codegen/generate null-function-ir 169 output 1024 0)
	<> x64-codegen/INVALID_IR [
	failures: failures + 1
]
put null-function-ir 108 1

; A tagged union stores its tag before the aligned shared payload. A write
; marks variant 1 after storing 73; TAG plus the payload must therefore be 74.
put tagged-ir 0 1
put tagged-ir 4 0
put tagged-ir 8 1
put tagged-ir 12 0
put tagged-ir 16 1
put tagged-ir 20 13
put tagged-ir 24 0
put tagged-ir 28 0

put tagged-ir 32 -3
put tagged-ir 36 0
put tagged-ir 40 1
put tagged-ir 44 0
put tagged-ir 48 1
put tagged-ir 52 -5
put tagged-ir 56 0

put tagged-ir 60 0
put tagged-ir 64 2
put tagged-ir 68 -5
put tagged-ir 72 0
put tagged-ir 76 0
put tagged-ir 80 0
put tagged-ir 84 0
put tagged-ir 88 1
put tagged-ir 92 13

put tagged-ir 96 1
put tagged-ir 100 1

put-instruction tagged-ir 104 3 1 1 0
put-instruction tagged-ir 120 6 0 1 0
put-instruction tagged-ir 136 1 -5 73 0
put-instruction tagged-ir 152 5 0 0 0
put-instruction tagged-ir 168 12 0 0 0
put-instruction tagged-ir 184 3 1 1 0
put-instruction tagged-ir 200 4 0 0 0
put-instruction tagged-ir 216 22 0 0 0
put-instruction tagged-ir 232 3 1 1 0
put-instruction tagged-ir 248 6 0 0 0
put-instruction tagged-ir 264 4 0 0 0
put-instruction tagged-ir 280 15 1 0 0
put-instruction tagged-ir 296 11 -5 0 0
tagged-ir/313: as byte! 66h
tagged-ir/314: as byte! 6Eh

size: x64-codegen/generate tagged-ir 314 output 1024 0
if size <= 0 [failures: failures + 1]
if size > 0 [
	fn: as codegen-function! (output + x64-codegen/IMAGE_HEADER_SIZE)
	if fn/frame-size <> 64 [failures: failures + 1]
	unless execute-selection? output 74 [failures: failures + 1]
]
put tagged-ir 40 0
if (x64-codegen/generate tagged-ir 314 output 1024 0) <> x64-codegen/INVALID_IR [
	failures: failures + 1
]
put tagged-ir 40 1
put tagged-ir 128 2
if (x64-codegen/generate tagged-ir 314 output 1024 0) <> x64-codegen/INVALID_IR [
	failures: failures + 1
]
put tagged-ir 128 1

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

; One array type owns no member records. Its logical count and slot width drive
; both static layout and the flat scalar initializer slice.
put array-ir 0 1
put array-ir 4 0
put array-ir 8 1
put array-ir 12 0
put array-ir 16 1
put array-ir 20 1
put array-ir 24 1
put array-ir 28 0

put array-ir 32 -7
put array-ir 36 -5
put array-ir 40 4
put array-ir 44 0
put array-ir 48 3

put array-ir 52 0
put array-ir 56 6
put array-ir 60 1
put array-ir 64 1
put array-ir 68 0
put array-ir 72 3

put array-ir 76 6
put array-ir 80 2
put array-ir 84 0
put array-ir 88 0
put array-ir 92 0
put array-ir 96 0
put array-ir 100 0
put array-ir 104 0
put array-ir 108 1

put array-ir 112 1
put array-ir 116 10
put array-ir 120 0
put array-ir 124 0
put array-ir 128 1
put array-ir 132 20
put array-ir 136 0
put array-ir 140 0
put array-ir 144 1
put array-ir 148 30
put array-ir 152 0
put array-ir 156 0

put-instruction array-ir 160 11 0 0 0
array-ir/177: as byte! 76h
array-ir/178: as byte! 61h
array-ir/179: as byte! 6Ch
array-ir/180: as byte! 75h
array-ir/181: as byte! 65h
array-ir/182: as byte! 73h
array-ir/183: as byte! 66h
array-ir/184: as byte! 6Eh

size: x64-codegen/generate array-ir 184 output 1024 0
if size <= 0 [
	failures: failures + 1
]
if size > 0 [
	header: as codegen-header! output
	image-global: as codegen-global! (output + x64-codegen/IMAGE_HEADER_SIZE
		+ x64-codegen/IMAGE_FUNCTION_SIZE)
	array-values: as int-ptr! (output + header/size - header/data-size
		+ image-global/data-offset)
	if any [
		header/global-count <> 1
		header/rodata-size <> 0
		image-global/flags <> 0
		image-global/data-offset <> x64-codegen/BITMAP_SIZE
		image-global/data-size <> 12
		array-values/1 <> 10 array-values/2 <> 20 array-values/3 <> 30
	][failures: failures + 1]
]
put array-ir 64 3
size: x64-codegen/generate array-ir 184 output 1024 0
if size <= 0 [
	failures: failures + 1
]
if size > 0 [
	header: as codegen-header! output
	image-global: as codegen-global! (output + x64-codegen/IMAGE_HEADER_SIZE
		+ x64-codegen/IMAGE_FUNCTION_SIZE)
	array-values: as int-ptr! (output + header/size - header/data-size
		- header/rodata-size + image-global/data-offset)
	if any [
		header/rodata-size <> 12
		header/data-size <> x64-codegen/BITMAP_SIZE
		image-global/flags <> x64-codegen/PROTECTED
		image-global/data-offset <> 0
		array-values/1 <> 10 array-values/2 <> 20 array-values/3 <> 30
	][failures: failures + 1]
]
put array-ir 64 4
if (x64-codegen/generate array-ir 184 output 1024 0) <> x64-codegen/INVALID_IR [
	failures: failures + 1
]
put array-ir 64 1
put array-ir 40 3
if (x64-codegen/generate array-ir 184 output 1024 0) <> x64-codegen/INVALID_IR [
	failures: failures + 1
]
put array-ir 40 4
put array-ir 112 3
if (x64-codegen/generate array-ir 184 output 1024 0) <> x64-codegen/INVALID_IR [
	failures: failures + 1
]
put array-ir 112 1

; Trimming the true edge and dropping the false value reconciles a
; value-less EITHER without emitting a native move.
put merge-ir 120 7
put merge-ir 124 1
if (x64-codegen/generate merge-ir 182 output 1024 0) <= 0 [failures: failures + 1]
put merge-ir 124 2
if (x64-codegen/generate merge-ir 182 output 1024 0) <> x64-codegen/INVALID_IR [
	failures: failures + 1
]

; A struct may contain a reference to itself because the reference layout is
; complete without walking the pointee inline.
put recursive-pointer-ir 0 1
put recursive-pointer-ir 4 0
put recursive-pointer-ir 8 2
put recursive-pointer-ir 12 0
put recursive-pointer-ir 16 1
put recursive-pointer-ir 20 1
put recursive-pointer-ir 24 0
put recursive-pointer-ir 28 0

put recursive-pointer-ir 32 -2
put recursive-pointer-ir 36 0
put recursive-pointer-ir 40 0
put recursive-pointer-ir 44 0
put recursive-pointer-ir 48 1

put recursive-pointer-ir 52 -6
put recursive-pointer-ir 56 1
put recursive-pointer-ir 60 0
put recursive-pointer-ir 64 1
put recursive-pointer-ir 68 0

put recursive-pointer-ir 72 2
put recursive-pointer-ir 76 0

put recursive-pointer-ir 80 0
put recursive-pointer-ir 84 2
put recursive-pointer-ir 88 0
put recursive-pointer-ir 92 0
put recursive-pointer-ir 96 0
put recursive-pointer-ir 100 0
put recursive-pointer-ir 104 0
put recursive-pointer-ir 108 0
put recursive-pointer-ir 112 1
put-instruction recursive-pointer-ir 116 11 0 0 0
recursive-pointer-ir/133: as byte! 66h
recursive-pointer-ir/134: as byte! 6Eh

if (x64-codegen/generate recursive-pointer-ir 134 output 1024 0) <= 0 [
	failures: failures + 1
]

; A by-value edge requires the complete child layout, so a self edge is an
; invalid type graph even when no function happens to use that type.
put recursive-value-ir 0 1
put recursive-value-ir 4 0
put recursive-value-ir 8 1
put recursive-value-ir 12 0
put recursive-value-ir 16 1
put recursive-value-ir 20 1
put recursive-value-ir 24 0
put recursive-value-ir 28 0

put recursive-value-ir 32 -2
put recursive-value-ir 36 0
put recursive-value-ir 40 0
put recursive-value-ir 44 0
put recursive-value-ir 48 1

put recursive-value-ir 52 1
put recursive-value-ir 56 1

put recursive-value-ir 60 0
put recursive-value-ir 64 2
put recursive-value-ir 68 0
put recursive-value-ir 72 0
put recursive-value-ir 76 0
put recursive-value-ir 80 0
put recursive-value-ir 84 0
put recursive-value-ir 88 0
put recursive-value-ir 92 1
put-instruction recursive-value-ir 96 11 0 0 0
recursive-value-ir/113: as byte! 66h
recursive-value-ir/114: as byte! 6Eh

if (x64-codegen/generate recursive-value-ir 114 output 1024 0)
	<> x64-codegen/INVALID_IR [
	failures: failures + 1
]

free output
free void-ir
free local-ir
free pointer-ir
free arithmetic-ir
free aggregate-ir
free abi-ir
free indirect-ir
free null-function-ir
free tagged-ir
free array-ir
free branch-ir
free merge-ir
free selection-ir
free recursive-pointer-ir
free recursive-value-ir
either failures = 0 [
	print ["PASS: typed postfix Windows x64 codegen" lf]
][
	print ["FAIL: typed postfix x64 codegen failures=" failures lf]
]
quit failures
