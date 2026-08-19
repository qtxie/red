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
void-ir: allocate 132
local-ir: allocate 260
pointer-ir: allocate 132
arithmetic-ir: allocate 260
aggregate-ir: allocate 516
abi-ir: allocate 1028
indirect-ir: allocate 324
variadic-ir: allocate 516
import-variadic-ir: allocate 260
null-function-ir: allocate 196
tagged-ir: allocate 388
array-ir: allocate 260
array-compare-ir: allocate 228
branch-ir: allocate 260
merge-ir: allocate 260
selection-ir: allocate 260
recursive-pointer-ir: allocate 164
recursive-value-ir: allocate 148
stack-ir: allocate 164
log-b-ir: allocate 132
system-ir: allocate 260
atomic-ir: allocate 276
overflow-ir: allocate 276
exception-ir: allocate 260
no-return-ir: allocate 148
header: declare codegen-header!
fn: declare codegen-function!
image-global: declare codegen-global!
array-values: as int-ptr! 0
if any [
	null? output null? void-ir null? local-ir null? pointer-ir null? arithmetic-ir
	null? aggregate-ir null? abi-ir null? indirect-ir null? variadic-ir
	null? import-variadic-ir null? null-function-ir
	null? tagged-ir null? array-ir null? array-compare-ir null? branch-ir
	null? merge-ir null? selection-ir null? recursive-pointer-ir null? recursive-value-ir
	null? stack-ir null? log-b-ir null? system-ir null? atomic-ir null? overflow-ir
	null? exception-ir null? no-return-ir
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

put void-ir 36 0
put void-ir 40 2
put void-ir 44 0
put void-ir 48 0
put void-ir 52 0
put void-ir 56 0
put void-ir 60 0
put void-ir 64 0
put void-ir 68 1
put-instruction void-ir 72 11 0 0 0
void-ir/89: as byte! 66h
void-ir/90: as byte! 6Eh

size: x64-codegen/generate void-ir 90 output 1024 0
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

if (x64-codegen/generate void-ir 89 output 1024 0) <> x64-codegen/INVALID_IR [
	failures: failures + 1
]
if (x64-codegen/generate void-ir 90 output 64 0) <> x64-codegen/OUTPUT_FULL [
	failures: failures + 1
]
if (x64-codegen/generate void-ir 90 output 1024 2) <> x64-codegen/UNSUPPORTED [
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

put local-ir 36 0
put local-ir 40 2
put local-ir 44 -5
put local-ir 48 0
put local-ir 52 0
put local-ir 56 0
put local-ir 60 0
put local-ir 64 1
put local-ir 68 7

put local-ir 72 -5
put local-ir 76 0
put-instruction local-ir 80 1 -5 7 0
put-instruction local-ir 96 3 1 1 0
put-instruction local-ir 112 5 0 0 0
put-instruction local-ir 128 12 0 0 0
put-instruction local-ir 144 3 1 1 0
put-instruction local-ir 160 4 0 0 0
put-instruction local-ir 176 11 -5 0 0
local-ir/193: as byte! 66h
local-ir/194: as byte! 6Eh

size: x64-codegen/generate local-ir 194 output 1024 0
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
put local-ir 60 1
if (x64-codegen/generate local-ir 194 output 1024 0) <> x64-codegen/INVALID_IR [
	failures: failures + 1
]
put local-ir 60 0
put local-ir 72 0
if (x64-codegen/generate local-ir 194 output 1024 0) <> x64-codegen/INVALID_IR [
	failures: failures + 1
]
put local-ir 72 -5

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
put pointer-ir 32 0
put pointer-ir 36 -6
put pointer-ir 40 -5
put pointer-ir 44 0
put pointer-ir 48 0
put pointer-ir 52 0
put pointer-ir 56 0
put pointer-ir 60 2
put pointer-ir 64 0
put pointer-ir 68 0
put pointer-ir 72 0
put pointer-ir 76 0
put pointer-ir 80 0
put pointer-ir 84 0
put pointer-ir 88 1
put-instruction pointer-ir 92 11 0 0 0
pointer-ir/109: as byte! 66h
pointer-ir/110: as byte! 6Eh

size: x64-codegen/generate pointer-ir 110 output 1024 0
if size <> 132 [failures: failures + 1]
put pointer-ir 40 0
if (x64-codegen/generate pointer-ir 110 output 1024 0) <> x64-codegen/INVALID_IR [
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
put arithmetic-ir 36 0
put arithmetic-ir 40 2
put arithmetic-ir 44 -5
put arithmetic-ir 48 0
put arithmetic-ir 52 0
put arithmetic-ir 56 0
put arithmetic-ir 60 0
put arithmetic-ir 64 0
put arithmetic-ir 68 6
put-instruction arithmetic-ir 72 1 -5 1 0
put-instruction arithmetic-ir 88 1 -5 2 0
put-instruction arithmetic-ir 104 15 1 0 0
put-instruction arithmetic-ir 120 1 -5 3 0
put-instruction arithmetic-ir 136 15 3 0 0
put-instruction arithmetic-ir 152 11 -5 0 0
arithmetic-ir/169: as byte! 66h
arithmetic-ir/170: as byte! 6Eh

size: x64-codegen/generate arithmetic-ir 170 output 1024 0
if size <= 0 [failures: failures + 1]
if size > 0 [
	fn: as codegen-function! (output + x64-codegen/IMAGE_HEADER_SIZE)
	if any [fn/frame-size <> 48 fn/code-size <= 17][failures: failures + 1]
]
put arithmetic-ir 92 -11
if (x64-codegen/generate arithmetic-ir 170 output 1024 0) <> x64-codegen/INVALID_IR [
	failures: failures + 1
]
put arithmetic-ir 92 -5
put arithmetic-ir 108 19
if (x64-codegen/generate arithmetic-ir 170 output 1024 0) <> x64-codegen/INVALID_IR [
	failures: failures + 1
]

; Two inline pair values occupy their own storage. LOAD exposes the source
; address, SET copies its layout, and the assignment result remains the target.
put aggregate-ir 0 1
put aggregate-ir 4 0
put aggregate-ir 8 1
put aggregate-ir 12 0
put aggregate-ir 16 1
put aggregate-ir 20 23
put aggregate-ir 24 0
put aggregate-ir 28 0
put aggregate-ir 32 0

put aggregate-ir 36 -2
put aggregate-ir 40 0
put aggregate-ir 44 0
put aggregate-ir 48 0
put aggregate-ir 52 2
put aggregate-ir 56 -5
put aggregate-ir 60 0
put aggregate-ir 64 -5
put aggregate-ir 68 0

put aggregate-ir 72 0
put aggregate-ir 76 2
put aggregate-ir 80 -5
put aggregate-ir 84 0
put aggregate-ir 88 0
put aggregate-ir 92 0
put aggregate-ir 96 0
put aggregate-ir 100 2
put aggregate-ir 104 23

put aggregate-ir 108 1
put aggregate-ir 112 1
put aggregate-ir 116 1
put aggregate-ir 120 1

put-instruction aggregate-ir 124 1 -5 17 0
put-instruction aggregate-ir 140 3 1 1 0
put-instruction aggregate-ir 156 6 0 0 0
put-instruction aggregate-ir 172 5 0 0 0
put-instruction aggregate-ir 188 12 0 0 0
put-instruction aggregate-ir 204 3 1 1 0
put-instruction aggregate-ir 220 4 0 0 0
put-instruction aggregate-ir 236 3 1 2 0
put-instruction aggregate-ir 252 5 0 0 0
put-instruction aggregate-ir 268 12 0 0 0
put-instruction aggregate-ir 284 1 -5 29 0
put-instruction aggregate-ir 300 3 1 2 0
put-instruction aggregate-ir 316 6 1 0 0
put-instruction aggregate-ir 332 5 0 0 0
put-instruction aggregate-ir 348 12 0 0 0
put-instruction aggregate-ir 364 3 1 2 0
put-instruction aggregate-ir 380 6 0 0 0
put-instruction aggregate-ir 396 4 0 0 0
put-instruction aggregate-ir 412 3 1 2 0
put-instruction aggregate-ir 428 6 1 0 0
put-instruction aggregate-ir 444 4 0 0 0
put-instruction aggregate-ir 460 15 1 0 0
put-instruction aggregate-ir 476 11 -5 0 0
aggregate-ir/493: as byte! 66h
aggregate-ir/494: as byte! 6Eh

size: x64-codegen/generate aggregate-ir 494 output 1024 0
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
put abi-ir 32 0

put abi-ir 36 -2
put abi-ir 40 0
put abi-ir 44 0
put abi-ir 48 0
put abi-ir 52 3

put abi-ir 56 -5
put abi-ir 60 0
put abi-ir 64 -5
put abi-ir 68 0
put abi-ir 72 -5
put abi-ir 76 0

put abi-ir 80 0
put abi-ir 84 4
put abi-ir 88 -5
put abi-ir 92 0
put abi-ir 96 0
put abi-ir 100 0
put abi-ir 104 0
put abi-ir 108 1
put abi-ir 112 25

put abi-ir 116 4
put abi-ir 120 2
put abi-ir 124 1
put abi-ir 128 4
put abi-ir 132 1
put abi-ir 136 1
put abi-ir 140 2
put abi-ir 144 0
put abi-ir 148 8

put abi-ir 152 1
put abi-ir 156 1
put abi-ir 160 1
put abi-ir 164 1

put-instruction abi-ir 168 1 -5 7 0
put-instruction abi-ir 184 3 1 1 0
put-instruction abi-ir 200 6 0 0 0
put-instruction abi-ir 216 5 0 0 0
put-instruction abi-ir 232 12 0 0 0
put-instruction abi-ir 248 1 -5 8 0
put-instruction abi-ir 264 3 1 1 0
put-instruction abi-ir 280 6 1 0 0
put-instruction abi-ir 296 5 0 0 0
put-instruction abi-ir 312 12 0 0 0
put-instruction abi-ir 328 1 -5 9 0
put-instruction abi-ir 344 3 1 1 0
put-instruction abi-ir 360 6 2 0 0
put-instruction abi-ir 376 5 0 0 0
put-instruction abi-ir 392 12 0 0 0
put-instruction abi-ir 408 3 1 1 0
put-instruction abi-ir 424 4 0 0 0
put-instruction abi-ir 440 7 2 1 1
put-instruction abi-ir 456 6 0 0 0
put-instruction abi-ir 472 4 0 0 0
put-instruction abi-ir 488 3 1 1 0
put-instruction abi-ir 504 6 0 0 0
put-instruction abi-ir 520 4 0 0 0
put-instruction abi-ir 536 15 1 0 0
put-instruction abi-ir 552 11 -5 0 0

put-instruction abi-ir 568 1 -5 70 0
put-instruction abi-ir 584 3 1 1 0
put-instruction abi-ir 600 6 0 0 0
put-instruction abi-ir 616 5 0 0 0
put-instruction abi-ir 632 12 0 0 0
put-instruction abi-ir 648 3 1 1 0
put-instruction abi-ir 664 4 0 0 0
put-instruction abi-ir 680 11 1 0 0
abi-ir/697: as byte! 6Dh
abi-ir/698: as byte! 61h
abi-ir/699: as byte! 69h
abi-ir/700: as byte! 6Eh
abi-ir/701: as byte! 69h
abi-ir/702: as byte! 64h

size: x64-codegen/generate abi-ir 702 output 1024 0
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
put indirect-ir 32 0

put indirect-ir 36 -4
put indirect-ir 40 -5
put indirect-ir 44 0
put indirect-ir 48 0
put indirect-ir 52 1

put indirect-ir 56 -5
put indirect-ir 60 0

put indirect-ir 64 0
put indirect-ir 68 1
put indirect-ir 72 -5
put indirect-ir 76 0
put indirect-ir 80 0
put indirect-ir 84 0
put indirect-ir 88 0
put indirect-ir 92 0
put indirect-ir 96 5

put indirect-ir 100 1
put indirect-ir 104 1
put indirect-ir 108 -5
put indirect-ir 112 0
put indirect-ir 116 0
put indirect-ir 120 1
put indirect-ir 124 1
put indirect-ir 128 0
put indirect-ir 132 5

put indirect-ir 136 -5
put indirect-ir 140 0

put-instruction indirect-ir 144 3 4 2 1
put-instruction indirect-ir 160 20 1 0 0
put-instruction indirect-ir 176 1 -5 41 0
put-instruction indirect-ir 192 7 0 1 1
put-instruction indirect-ir 208 11 -5 0 0

put-instruction indirect-ir 224 3 1 1 0
put-instruction indirect-ir 240 4 0 0 0
put-instruction indirect-ir 256 1 -5 1 0
put-instruction indirect-ir 272 15 1 0 0
put-instruction indirect-ir 288 11 -5 0 0
indirect-ir/305: as byte! 6Dh
indirect-ir/306: as byte! 69h

size: x64-codegen/generate indirect-ir 306 output 1024 0
if size <= 0 [
	failures: failures + 1
]
if size > 0 [
	header: as codegen-header! output
	if header/function-count <> 2 [failures: failures + 1]
	unless execute-first? output 42 [failures: failures + 1]
]
put indirect-ir 204 -5
if (x64-codegen/generate indirect-ir 306 output 1024 0) <> x64-codegen/INVALID_IR [
	failures: failures + 1
]
put indirect-ir 204 1

; Native variadic CALL keeps source values in the postfix stream. The caller
; packs them into one forward-order uint64 list and passes count/list/size.
; The callee returns list/1 + list/2 + count + size = 51.
put variadic-ir 0 1
put variadic-ir 4 0
put variadic-ir 8 1
put variadic-ir 12 0
put variadic-ir 16 2
put variadic-ir 20 22
put variadic-ir 24 0
put variadic-ir 28 0
put variadic-ir 32 0

put variadic-ir 36 -6
put variadic-ir 40 -8
put variadic-ir 44 0
put variadic-ir 48 0
put variadic-ir 52 0

put variadic-ir 56 0
put variadic-ir 60 4
put variadic-ir 64 -5
put variadic-ir 68 0
put variadic-ir 72 0
put variadic-ir 76 0
put variadic-ir 80 0
put variadic-ir 84 0
put variadic-ir 88 4

put variadic-ir 92 4
put variadic-ir 96 8
put variadic-ir 100 -5
put variadic-ir 104 8
put variadic-ir 108 0
put variadic-ir 112 3
put variadic-ir 116 3
put variadic-ir 120 0
put variadic-ir 124 18

put variadic-ir 128 -5
put variadic-ir 132 0
put variadic-ir 136 1
put variadic-ir 140 0
put variadic-ir 144 -5
put variadic-ir 148 0

put-instruction variadic-ir 152 1 -5 11 0
put-instruction variadic-ir 168 1 -5 22 0
put-instruction variadic-ir 184 7 2 2 -5
put-instruction variadic-ir 200 11 -5 0 0

put-instruction variadic-ir 216 3 1 2 0
put-instruction variadic-ir 232 4 0 0 0
put-instruction variadic-ir 248 21 0 0 0
put-instruction variadic-ir 264 4 0 0 0
put-instruction variadic-ir 280 8 -5 0 0
put-instruction variadic-ir 296 3 1 2 0
put-instruction variadic-ir 312 4 0 0 0
put-instruction variadic-ir 328 21 1 0 0
put-instruction variadic-ir 344 4 0 0 0
put-instruction variadic-ir 360 8 -5 0 0
put-instruction variadic-ir 376 15 1 0 0
put-instruction variadic-ir 392 3 1 1 0
put-instruction variadic-ir 408 4 0 0 0
put-instruction variadic-ir 424 15 1 0 0
put-instruction variadic-ir 440 3 1 3 0
put-instruction variadic-ir 456 4 0 0 0
put-instruction variadic-ir 472 15 1 0 0
put-instruction variadic-ir 488 11 -5 0 0
variadic-ir/505: as byte! 6Dh
variadic-ir/506: as byte! 61h
variadic-ir/507: as byte! 69h
variadic-ir/508: as byte! 6Eh
variadic-ir/509: as byte! 76h
variadic-ir/510: as byte! 61h
variadic-ir/511: as byte! 72h
variadic-ir/512: as byte! 69h
variadic-ir/513: as byte! 61h
variadic-ir/514: as byte! 64h
variadic-ir/515: as byte! 69h
variadic-ir/516: as byte! 63h

size: x64-codegen/generate variadic-ir 516 output 1024 0
if size <= 0 [failures: failures + 1]
if size > 0 [
	header: as codegen-header! output
	if header/function-count <> 2 [failures: failures + 1]
	unless execute-first? output 51 [failures: failures + 1]
]
put variadic-ir 136 -5
if (x64-codegen/generate variadic-ir 516 output 1024 0) <> x64-codegen/INVALID_IR [
	failures: failures + 1
]
put variadic-ir 136 1

; Imported native variadic functions have no count/list declaration in IR.
; Their flags still select the same packed call ABI at the call site.
put import-variadic-ir 0 1
put import-variadic-ir 4 0
put import-variadic-ir 8 0
put import-variadic-ir 12 1
put import-variadic-ir 16 1
put import-variadic-ir 20 4
put import-variadic-ir 24 0
put import-variadic-ir 28 0
put import-variadic-ir 32 0

put import-variadic-ir 36 0
put import-variadic-ir 40 7
put import-variadic-ir 44 7
put import-variadic-ir 48 4
put import-variadic-ir 52 -5
put import-variadic-ir 56 10
put import-variadic-ir 60 0
put import-variadic-ir 64 0

put import-variadic-ir 68 11
put import-variadic-ir 72 4
put import-variadic-ir 76 -5
put import-variadic-ir 80 0
put import-variadic-ir 84 0
put import-variadic-ir 88 0
put import-variadic-ir 92 0
put import-variadic-ir 96 0
put import-variadic-ir 100 4

put-instruction import-variadic-ir 104 1 -5 11 0
put-instruction import-variadic-ir 120 1 -5 22 0
put-instruction import-variadic-ir 136 7 -1 2 -5
put-instruction import-variadic-ir 152 11 -5 0 0
import-variadic-ir/169: as byte! 66h
import-variadic-ir/170: as byte! 6Fh
import-variadic-ir/171: as byte! 6Fh
import-variadic-ir/172: as byte! 2Eh
import-variadic-ir/173: as byte! 64h
import-variadic-ir/174: as byte! 6Ch
import-variadic-ir/175: as byte! 6Ch
import-variadic-ir/176: as byte! 73h
import-variadic-ir/177: as byte! 69h
import-variadic-ir/178: as byte! 6Eh
import-variadic-ir/179: as byte! 6Bh
import-variadic-ir/180: as byte! 6Dh
import-variadic-ir/181: as byte! 61h
import-variadic-ir/182: as byte! 69h
import-variadic-ir/183: as byte! 6Eh

size: x64-codegen/generate import-variadic-ir 183 output 1024 0
if size <= 0 [failures: failures + 1]
if size > 0 [
	header: as codegen-header! output
	if any [header/function-count <> 1 header/import-count <> 1][
		failures: failures + 1
	]
]

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
put null-function-ir 32 0

put null-function-ir 36 -4
put null-function-ir 40 -5
put null-function-ir 44 0
put null-function-ir 48 0
put null-function-ir 52 0

put null-function-ir 56 0
put null-function-ir 60 1
put null-function-ir 64 -11
put null-function-ir 68 0
put null-function-ir 72 0
put null-function-ir 76 0
put null-function-ir 80 0
put null-function-ir 84 0
put null-function-ir 88 5

put-instruction null-function-ir 92 1 -14 0 0
put-instruction null-function-ir 108 8 1 0 0
put-instruction null-function-ir 124 1 -14 0 0
put-instruction null-function-ir 140 15 13 0 0
put-instruction null-function-ir 156 11 -11 0 0
null-function-ir/173: as byte! 6Eh

size: x64-codegen/generate null-function-ir 173 output 1024 0
if size <= 0 [
	failures: failures + 1
]
if size > 0 [
	unless execute-selection? output 1 [failures: failures + 1]
]
put null-function-ir 112 -2
if (x64-codegen/generate null-function-ir 173 output 1024 0)
	<> x64-codegen/INVALID_IR [
	failures: failures + 1
]
put null-function-ir 112 1

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
put tagged-ir 32 0

put tagged-ir 36 -3
put tagged-ir 40 0
put tagged-ir 44 1
put tagged-ir 48 0
put tagged-ir 52 1
put tagged-ir 56 -5
put tagged-ir 60 0

put tagged-ir 64 0
put tagged-ir 68 2
put tagged-ir 72 -5
put tagged-ir 76 0
put tagged-ir 80 0
put tagged-ir 84 0
put tagged-ir 88 0
put tagged-ir 92 1
put tagged-ir 96 13

put tagged-ir 100 1
put tagged-ir 104 1

put-instruction tagged-ir 108 1 -5 73 0
put-instruction tagged-ir 124 3 1 1 0
put-instruction tagged-ir 140 6 0 1 0
put-instruction tagged-ir 156 5 0 0 0
put-instruction tagged-ir 172 12 0 0 0
put-instruction tagged-ir 188 3 1 1 0
put-instruction tagged-ir 204 4 0 0 0
put-instruction tagged-ir 220 22 0 0 0
put-instruction tagged-ir 236 3 1 1 0
put-instruction tagged-ir 252 6 0 0 0
put-instruction tagged-ir 268 4 0 0 0
put-instruction tagged-ir 284 15 1 0 0
put-instruction tagged-ir 300 11 -5 0 0
tagged-ir/317: as byte! 66h
tagged-ir/318: as byte! 6Eh

size: x64-codegen/generate tagged-ir 318 output 1024 0
if size <= 0 [failures: failures + 1]
if size > 0 [
	fn: as codegen-function! (output + x64-codegen/IMAGE_HEADER_SIZE)
	if fn/frame-size <> 64 [failures: failures + 1]
	unless execute-selection? output 74 [failures: failures + 1]
]
put tagged-ir 44 0
if (x64-codegen/generate tagged-ir 318 output 1024 0) <> x64-codegen/INVALID_IR [
	failures: failures + 1
]
put tagged-ir 44 1
put tagged-ir 132 2
if (x64-codegen/generate tagged-ir 318 output 1024 0) <> x64-codegen/INVALID_IR [
	failures: failures + 1
]
put tagged-ir 132 1

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
put branch-ir 36 0
put branch-ir 40 2
put branch-ir 44 -5
put branch-ir 48 0
put branch-ir 52 0
put branch-ir 56 0
put branch-ir 60 0
put branch-ir 64 0
put branch-ir 68 6
put-instruction branch-ir 72 1 -11 1 0
put-instruction branch-ir 88 17 5 0 0
put-instruction branch-ir 104 1 -5 7 0
put-instruction branch-ir 120 11 -5 0 0
put-instruction branch-ir 136 1 -5 9 0
put-instruction branch-ir 152 11 -5 0 0
branch-ir/169: as byte! 66h
branch-ir/170: as byte! 6Eh

size: x64-codegen/generate branch-ir 170 output 1024 0
if size <= 0 [failures: failures + 1]
put branch-ir 92 7
if (x64-codegen/generate branch-ir 170 output 1024 0) <> x64-codegen/INVALID_IR [
	failures: failures + 1
]
put branch-ir 92 5
put branch-ir 96 2
if (x64-codegen/generate branch-ir 170 output 1024 0) <> x64-codegen/INVALID_IR [
	failures: failures + 1
]
put branch-ir 96 0
put branch-ir 76 -5
if (x64-codegen/generate branch-ir 170 output 1024 0) <> x64-codegen/INVALID_IR [
	failures: failures + 1
]
put branch-ir 76 -11
put branch-ir 92 4
if (x64-codegen/generate branch-ir 170 output 1024 0) <> x64-codegen/INVALID_IR [
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
put merge-ir 36 0
put merge-ir 40 2
put merge-ir 44 0
put merge-ir 48 0
put merge-ir 52 0
put merge-ir 56 0
put merge-ir 60 0
put merge-ir 64 0
put merge-ir 68 7
put-instruction merge-ir 72 1 -11 1 0
put-instruction merge-ir 88 17 5 0 0
put-instruction merge-ir 104 1 -5 7 0
put-instruction merge-ir 120 16 6 0 0
put-instruction merge-ir 136 1 -5 9 0
put-instruction merge-ir 152 12 0 0 0
put-instruction merge-ir 168 11 0 0 0
merge-ir/185: as byte! 66h
merge-ir/186: as byte! 6Eh

if (x64-codegen/generate merge-ir 186 output 1024 0) <= 0 [failures: failures + 1]
put merge-ir 140 -11
if (x64-codegen/generate merge-ir 186 output 1024 0) <> x64-codegen/INVALID_IR [
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
put selection-ir 36 0
put selection-ir 40 2
put selection-ir 44 -5
put selection-ir 48 0
put selection-ir 52 0
put selection-ir 56 0
put selection-ir 60 0
put selection-ir 64 0
put selection-ir 68 7
put selection-ir 72 2
put selection-ir 76 0
put selection-ir 80 5
put-instruction selection-ir 84 1 -5 2 0
put-instruction selection-ir 100 18 0 1 3
put-instruction selection-ir 116 1 -5 9 0
put-instruction selection-ir 132 11 -5 0 0
put-instruction selection-ir 148 1 -5 7 0
put-instruction selection-ir 164 11 -5 0 0
put-instruction selection-ir 180 19 101 0 0
selection-ir/197: as byte! 66h
selection-ir/198: as byte! 6Eh

if (x64-codegen/generate selection-ir 198 output 1024 0) <= 0 [
	failures: failures + 1
]
unless execute-selection? output 7 [failures: failures + 1]
put selection-ir 92 9
if (x64-codegen/generate selection-ir 198 output 1024 0) <= 0 [
	failures: failures + 1
]
unless execute-selection? output 9 [failures: failures + 1]
put selection-ir 92 2

put selection-ir 88 -7
if (x64-codegen/generate selection-ir 198 output 1024 0) <= 0 [
	failures: failures + 1
]
unless execute-selection? output 7 [failures: failures + 1]

put selection-ir 88 -2
put selection-ir 92 65
put selection-ir 72 65
if (x64-codegen/generate selection-ir 198 output 1024 0) <= 0 [
	failures: failures + 1
]
unless execute-selection? output 7 [failures: failures + 1]
put selection-ir 88 -5
put selection-ir 92 2
put selection-ir 72 2

put selection-ir 104 1
if (x64-codegen/generate selection-ir 198 output 1024 0) <> x64-codegen/INVALID_IR [
	failures: failures + 1
]
put selection-ir 104 0
put selection-ir 108 2
if (x64-codegen/generate selection-ir 198 output 1024 0) <> x64-codegen/INVALID_IR [
	failures: failures + 1
]
put selection-ir 108 1
put selection-ir 80 0
if (x64-codegen/generate selection-ir 198 output 1024 0) <> x64-codegen/INVALID_IR [
	failures: failures + 1
]
put selection-ir 80 5
put selection-ir 184 0
if (x64-codegen/generate selection-ir 198 output 1024 0) <> x64-codegen/INVALID_IR [
	failures: failures + 1
]
put selection-ir 184 101

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
put array-ir 32 0

put array-ir 36 -7
put array-ir 40 -5
put array-ir 44 4
put array-ir 48 0
put array-ir 52 3

put array-ir 56 0
put array-ir 60 6
put array-ir 64 1
put array-ir 68 1
put array-ir 72 0
put array-ir 76 3

put array-ir 80 6
put array-ir 84 2
put array-ir 88 0
put array-ir 92 0
put array-ir 96 0
put array-ir 100 0
put array-ir 104 0
put array-ir 108 0
put array-ir 112 1

put array-ir 116 1
put array-ir 120 10
put array-ir 124 0
put array-ir 128 0
put array-ir 132 1
put array-ir 136 20
put array-ir 140 0
put array-ir 144 0
put array-ir 148 1
put array-ir 152 30
put array-ir 156 0
put array-ir 160 0

put-instruction array-ir 164 11 0 0 0
array-ir/181: as byte! 76h
array-ir/182: as byte! 61h
array-ir/183: as byte! 6Ch
array-ir/184: as byte! 75h
array-ir/185: as byte! 65h
array-ir/186: as byte! 73h
array-ir/187: as byte! 66h
array-ir/188: as byte! 6Eh

size: x64-codegen/generate array-ir 188 output 1024 0
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
put array-ir 68 3
size: x64-codegen/generate array-ir 188 output 1024 0
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
put array-ir 68 4
if (x64-codegen/generate array-ir 188 output 1024 0) <> x64-codegen/INVALID_IR [
	failures: failures + 1
]
put array-ir 68 1
put array-ir 44 3
if (x64-codegen/generate array-ir 188 output 1024 0) <> x64-codegen/INVALID_IR [
	failures: failures + 1
]
put array-ir 44 4
put array-ir 116 3
if (x64-codegen/generate array-ir 188 output 1024 0) <> x64-codegen/INVALID_IR [
	failures: failures + 1
]
put array-ir 116 1

; Literal arrays compare as pointers only when their element types match.
put array-compare-ir 0 1
put array-compare-ir 4 0
put array-compare-ir 8 2
put array-compare-ir 12 0
put array-compare-ir 16 1
put array-compare-ir 20 5
put array-compare-ir 24 0
put array-compare-ir 28 0
put array-compare-ir 32 0

put array-compare-ir 36 -7
put array-compare-ir 40 -5
put array-compare-ir 44 4
put array-compare-ir 48 0
put array-compare-ir 52 3

put array-compare-ir 56 -6
put array-compare-ir 60 -5
put array-compare-ir 64 0
put array-compare-ir 68 0
put array-compare-ir 72 0

put array-compare-ir 76 0
put array-compare-ir 80 2
put array-compare-ir 84 -11
put array-compare-ir 88 0
put array-compare-ir 92 0
put array-compare-ir 96 0
put array-compare-ir 100 0
put array-compare-ir 104 0
put array-compare-ir 108 5

put-instruction array-compare-ir 112 1 1 0 0
put-instruction array-compare-ir 128 13 0 0 0
put-instruction array-compare-ir 144 8 2 0 0
put-instruction array-compare-ir 160 15 15 0 0
put-instruction array-compare-ir 176 11 -11 0 0
array-compare-ir/193: as byte! 66h
array-compare-ir/194: as byte! 6Eh

size: x64-codegen/generate array-compare-ir 194 output 1024 0
if any [size <= 0 not execute-first? output 0][failures: failures + 1]
put array-compare-ir 60 -15
if (x64-codegen/generate array-compare-ir 194 output 1024 0)
	<> x64-codegen/INVALID_IR [
	failures: failures + 1
]

; Trimming the true edge and dropping the false value reconciles a
; value-less EITHER without emitting a native move.
put merge-ir 124 7
put merge-ir 128 1
if (x64-codegen/generate merge-ir 186 output 1024 0) <= 0 [failures: failures + 1]
put merge-ir 128 2
if (x64-codegen/generate merge-ir 186 output 1024 0) <> x64-codegen/INVALID_IR [
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
put recursive-pointer-ir 32 0

put recursive-pointer-ir 36 -2
put recursive-pointer-ir 40 0
put recursive-pointer-ir 44 0
put recursive-pointer-ir 48 0
put recursive-pointer-ir 52 1

put recursive-pointer-ir 56 -6
put recursive-pointer-ir 60 1
put recursive-pointer-ir 64 0
put recursive-pointer-ir 68 1
put recursive-pointer-ir 72 0

put recursive-pointer-ir 76 2
put recursive-pointer-ir 80 0

put recursive-pointer-ir 84 0
put recursive-pointer-ir 88 2
put recursive-pointer-ir 92 0
put recursive-pointer-ir 96 0
put recursive-pointer-ir 100 0
put recursive-pointer-ir 104 0
put recursive-pointer-ir 108 0
put recursive-pointer-ir 112 0
put recursive-pointer-ir 116 1
put-instruction recursive-pointer-ir 120 11 0 0 0
recursive-pointer-ir/137: as byte! 66h
recursive-pointer-ir/138: as byte! 6Eh

if (x64-codegen/generate recursive-pointer-ir 138 output 1024 0) <= 0 [
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
put recursive-value-ir 32 0

put recursive-value-ir 36 -2
put recursive-value-ir 40 0
put recursive-value-ir 44 0
put recursive-value-ir 48 0
put recursive-value-ir 52 1

put recursive-value-ir 56 1
put recursive-value-ir 60 1

put recursive-value-ir 64 0
put recursive-value-ir 68 2
put recursive-value-ir 72 0
put recursive-value-ir 76 0
put recursive-value-ir 80 0
put recursive-value-ir 84 0
put recursive-value-ir 88 0
put recursive-value-ir 92 0
put recursive-value-ir 96 1
put-instruction recursive-value-ir 100 11 0 0 0
recursive-value-ir/117: as byte! 66h
recursive-value-ir/118: as byte! 6Eh

if (x64-codegen/generate recursive-value-ir 118 output 1024 0)
	<> x64-codegen/INVALID_IR [
	failures: failures + 1
]

; Native stack operations consume and produce ordinary typed postfix values.
put stack-ir 0 1
put stack-ir 4 0
put stack-ir 8 0
put stack-ir 12 0
put stack-ir 16 1
put stack-ir 20 4
put stack-ir 24 0
put stack-ir 28 0
put stack-ir 32 0

put stack-ir 36 0
put stack-ir 40 2
put stack-ir 44 -5
put stack-ir 48 0
put stack-ir 52 0
put stack-ir 56 0
put stack-ir 60 0
put stack-ir 64 0
put stack-ir 68 4

put-instruction stack-ir 72 1 -5 42 0
put-instruction stack-ir 88 10 2 0 0
put-instruction stack-ir 104 10 3 0 0
put-instruction stack-ir 120 11 -5 0 0
stack-ir/137: as byte! 66h
stack-ir/138: as byte! 6Eh

size: x64-codegen/generate stack-ir 138 output 1024 0
if any [size <= 0 not execute-first? output 42][failures: failures + 1]
put stack-ir 96 1
if (x64-codegen/generate stack-ir 138 output 1024 0) <> x64-codegen/INVALID_IR [
	failures: failures + 1
]
put stack-ir 96 0
put stack-ir 92 23
if (x64-codegen/generate stack-ir 138 output 1024 0) <> x64-codegen/UNSUPPORTED [
	failures: failures + 1
]
put stack-ir 92 2

; LOG-B consumes one integer value and replaces it with an integer! result.
put log-b-ir 0 1
put log-b-ir 4 0
put log-b-ir 8 0
put log-b-ir 12 0
put log-b-ir 16 1
put log-b-ir 20 3
put log-b-ir 24 0
put log-b-ir 28 0
put log-b-ir 32 0

put log-b-ir 36 0
put log-b-ir 40 2
put log-b-ir 44 -5
put log-b-ir 48 0
put log-b-ir 52 0
put log-b-ir 56 0
put log-b-ir 60 0
put log-b-ir 64 0
put log-b-ir 68 3

put-instruction log-b-ir 72 1 -5 256 0
put-instruction log-b-ir 88 10 22 0 -5
put-instruction log-b-ir 104 11 -5 0 0
log-b-ir/121: as byte! 6Ch
log-b-ir/122: as byte! 62h

size: x64-codegen/generate log-b-ir 122 output 1024 0
if any [size <= 0 not execute-first? output 8][failures: failures + 1]
put log-b-ir 76 -11
if (x64-codegen/generate log-b-ir 122 output 1024 0) <> x64-codegen/INVALID_IR [
	failures: failures + 1
]
put log-b-ir 76 -5
put log-b-ir 100 -11
if (x64-codegen/generate log-b-ir 122 output 1024 0) <> x64-codegen/INVALID_IR [
	failures: failures + 1
]
put log-b-ir 100 -5

; PC, general registers, and overflow flags are typed native effects. Their
; machine state is consumed immediately, without a source-shaped adapter.
put system-ir 0 1
put system-ir 4 0
put system-ir 8 1
put system-ir 12 0
put system-ir 16 1
put system-ir 20 4
put system-ir 24 0
put system-ir 28 0
put system-ir 32 0

put system-ir 36 -6
put system-ir 40 -15
put system-ir 44 0
put system-ir 48 0
put system-ir 52 0

put system-ir 56 0
put system-ir 60 2
put system-ir 64 -11
put system-ir 68 0
put system-ir 72 0
put system-ir 76 0
put system-ir 80 0
put system-ir 84 0
put system-ir 88 4

put-instruction system-ir 92 10 13 0 1
put-instruction system-ir 108 1 -14 0 0
put-instruction system-ir 124 15 14 0 0
put-instruction system-ir 140 11 -11 0 0
system-ir/157: as byte! 66h
system-ir/158: as byte! 6Eh

size: x64-codegen/generate system-ir 158 output 1024 0
if any [size <= 0 not execute-first? output 1][failures: failures + 1]
put system-ir 40 -5
if (x64-codegen/generate system-ir 158 output 1024 0) <> x64-codegen/INVALID_IR [
	failures: failures + 1
]

; system/cpu/rcx: 42 followed immediately by system/cpu/rcx returns 42.
put system-ir 20 5
put system-ir 40 -5
put system-ir 64 1
put system-ir 88 5
put-instruction system-ir 92 1 1 42 0
put-instruction system-ir 108 10 15 1 1
put-instruction system-ir 124 12 0 0 0
put-instruction system-ir 140 10 14 1 1
put-instruction system-ir 156 11 1 0 0
system-ir/173: as byte! 66h
system-ir/174: as byte! 6Eh

size: x64-codegen/generate system-ir 174 output 1024 0
if any [size <= 0 not execute-first? output 42][failures: failures + 1]
put system-ir 116 16
if (x64-codegen/generate system-ir 174 output 1024 0) <> x64-codegen/INVALID_IR [
	failures: failures + 1
]
put system-ir 116 1

; ADD sets OF while the division family has no usable OF result.
put system-ir 64 -11
put-instruction system-ir 92 1 -5 2147483647 0
put-instruction system-ir 108 1 -5 1 0
put-instruction system-ir 124 15 1 0 0
put-instruction system-ir 140 10 16 0 -11
put-instruction system-ir 156 11 -11 0 0
size: x64-codegen/generate system-ir 174 output 1024 0
if any [size <= 0 not execute-first? output 1][failures: failures + 1]

put-instruction system-ir 108 1 -5 -1 -1
put-instruction system-ir 124 15 4 0 0
size: x64-codegen/generate system-ir 174 output 1024 0
if any [size <= 0 not execute-first? output 0][failures: failures + 1]
put system-ir 152 0
if (x64-codegen/generate system-ir 174 output 1024 0) <> x64-codegen/INVALID_IR [
	failures: failures + 1
]

; false or overflow? [2147483647 + 1]. The overflow edge enters with the
; scope's original stack depth, leaving the outer logic operand intact.
put overflow-ir 0 1
put overflow-ir 4 0
put overflow-ir 8 0
put overflow-ir 12 0
put overflow-ir 16 1
put overflow-ir 20 11
put overflow-ir 24 0
put overflow-ir 28 0
put overflow-ir 32 0

put overflow-ir 36 0
put overflow-ir 40 2
put overflow-ir 44 -11
put overflow-ir 48 0
put overflow-ir 52 0
put overflow-ir 56 0
put overflow-ir 60 0
put overflow-ir 64 0
put overflow-ir 68 11

put-instruction overflow-ir 72 1 -11 0 0
put-instruction overflow-ir 88 23 9 0 0
put-instruction overflow-ir 104 1 -5 2147483647 0
put-instruction overflow-ir 120 1 -5 1 0
put-instruction overflow-ir 136 15 1 2 0
put-instruction overflow-ir 152 12 0 0 0
put-instruction overflow-ir 168 1 -11 0 0
put-instruction overflow-ir 184 16 10 0 0
put-instruction overflow-ir 200 1 -11 1 0
put-instruction overflow-ir 216 15 10 0 0
put-instruction overflow-ir 232 11 -11 0 0
overflow-ir/249: as byte! 66h
overflow-ir/250: as byte! 6Eh

size: x64-codegen/generate overflow-ir 250 output 1024 0
if any [size <= 0 not execute-first? output 1][failures: failures + 1]
put overflow-ir 112 1
size: x64-codegen/generate overflow-ir 250 output 1024 0
if any [size <= 0 not execute-first? output 0][failures: failures + 1]
put overflow-ir 112 2147483647

put overflow-ir 92 0
if (x64-codegen/generate overflow-ir 250 output 1024 0) <> x64-codegen/INVALID_IR [
	failures: failures + 1
]
put overflow-ir 92 9
put overflow-ir 144 5
if (x64-codegen/generate overflow-ir 250 output 1024 0) <> x64-codegen/INVALID_IR [
	failures: failures + 1
]
put overflow-ir 144 2
put overflow-ir 148 1
if (x64-codegen/generate overflow-ir 250 output 1024 0) <> x64-codegen/INVALID_IR [
	failures: failures + 1
]
put overflow-ir 148 0

; Atomic math consumes an ordinary pointer and value pair. The /old bit is
; semantic metadata on the native operation, not a source-shaped instruction.
put atomic-ir 0 1
put atomic-ir 4 0
put atomic-ir 8 1
put atomic-ir 12 0
put atomic-ir 16 1
put atomic-ir 20 9
put atomic-ir 24 0
put atomic-ir 28 0
put atomic-ir 32 0

put atomic-ir 36 -6
put atomic-ir 40 -5
put atomic-ir 44 0
put atomic-ir 48 0
put atomic-ir 52 0

put atomic-ir 56 0
put atomic-ir 60 2
put atomic-ir 64 -5
put atomic-ir 68 0
put atomic-ir 72 0
put atomic-ir 76 0
put atomic-ir 80 0
put atomic-ir 84 1
put atomic-ir 88 9

put atomic-ir 92 -5
put atomic-ir 96 0

put-instruction atomic-ir 100 1 -5 7 0
put-instruction atomic-ir 116 3 1 1 0
put-instruction atomic-ir 132 5 0 0 0
put-instruction atomic-ir 148 12 0 0 0
put-instruction atomic-ir 164 3 1 1 0
put-instruction atomic-ir 180 20 1 0 0
put-instruction atomic-ir 196 1 -5 5 0
put-instruction atomic-ir 212 10 21 9 -5
put-instruction atomic-ir 228 11 -5 0 0
atomic-ir/245: as byte! 66h
atomic-ir/246: as byte! 6Eh

size: x64-codegen/generate atomic-ir 246 output 1024 0
if any [size <= 0 not execute-first? output 7][failures: failures + 1]
put atomic-ir 220 0
if (x64-codegen/generate atomic-ir 246 output 1024 0) <> x64-codegen/INVALID_IR [
	failures: failures + 1
]
put atomic-ir 220 9
put atomic-ir 224 -11
if (x64-codegen/generate atomic-ir 246 output 1024 0) <> x64-codegen/INVALID_IR [
	failures: failures + 1
]
put atomic-ir 224 -5
put atomic-ir 40 -2
if (x64-codegen/generate atomic-ir 246 output 1024 0) <> x64-codegen/INVALID_IR [
	failures: failures + 1
]

; A lexical CATCH owns one fixed frame record. THROW resumes at END_CATCH,
; which restores the previous threshold, resume address, and stack pointer.
put exception-ir 0 1
put exception-ir 4 0
put exception-ir 8 0
put exception-ir 12 0
put exception-ir 16 1
put exception-ir 20 7
put exception-ir 24 0
put exception-ir 28 0
put exception-ir 32 0

put exception-ir 36 0
put exception-ir 40 2
put exception-ir 44 -5
put exception-ir 48 0
put exception-ir 52 0
put exception-ir 56 0
put exception-ir 60 0
put exception-ir 64 0
put exception-ir 68 7

put-instruction exception-ir 72 1 -5 1 0
put-instruction exception-ir 88 24 5 1 0
put-instruction exception-ir 104 1 -5 1 0
put-instruction exception-ir 120 26 0 0 0
put-instruction exception-ir 136 25 2 1 0
put-instruction exception-ir 152 1 -5 73 0
put-instruction exception-ir 168 11 -5 0 0
exception-ir/185: as byte! 66h
exception-ir/186: as byte! 6Eh

size: x64-codegen/generate exception-ir 186 output 1024 0
if any [size <= 0 not execute-selection? output 73][failures: failures + 1]
put exception-ir 92 6
if (x64-codegen/generate exception-ir 186 output 1024 0) <> x64-codegen/INVALID_IR [
	failures: failures + 1
]
put exception-ir 92 5
put exception-ir 96 2
if (x64-codegen/generate exception-ir 186 output 1024 0) <> x64-codegen/INVALID_IR [
	failures: failures + 1
]
put exception-ir 96 1
put exception-ir 76 -11
if (x64-codegen/generate exception-ir 186 output 1024 0) <> x64-codegen/INVALID_IR [
	failures: failures + 1
]
put exception-ir 76 -5
put exception-ir 108 -11
if (x64-codegen/generate exception-ir 186 output 1024 0) <> x64-codegen/INVALID_IR [
	failures: failures + 1
]
put exception-ir 108 -5

; JUMP carries only the number of lexical catch records it exits.
put exception-ir 112 73
put-instruction exception-ir 120 16 6 1 1
size: x64-codegen/generate exception-ir 186 output 1024 0
if any [size <= 0 not execute-selection? output 73][failures: failures + 1]
put exception-ir 132 0
if (x64-codegen/generate exception-ir 186 output 1024 0) <> x64-codegen/INVALID_IR [
	failures: failures + 1
]
put exception-ir 132 1

put exception-ir 48 (x64-codegen/CATCH_FLAG + x64-codegen/CDECL)
if (x64-codegen/generate exception-ir 186 output 1024 0) <> x64-codegen/INVALID_IR [
	failures: failures + 1
]

; A direct call to a concrete no-return function terminates the caller CFG.
put no-return-ir 0 1
put no-return-ir 4 0
put no-return-ir 8 0
put no-return-ir 12 0
put no-return-ir 16 2
put no-return-ir 20 2
put no-return-ir 24 0
put no-return-ir 28 0
put no-return-ir 32 0

put no-return-ir 36 0
put no-return-ir 40 2
put no-return-ir 44 0
put no-return-ir 48 0
put no-return-ir 52 0
put no-return-ir 56 0
put no-return-ir 60 0
put no-return-ir 64 0
put no-return-ir 68 1

put no-return-ir 72 2
put no-return-ir 76 2
put no-return-ir 80 0
put no-return-ir 84 x64-codegen/NO_RETURN
put no-return-ir 88 0
put no-return-ir 92 0
put no-return-ir 96 0
put no-return-ir 100 0
put no-return-ir 104 1

put-instruction no-return-ir 108 7 2 0 0
put-instruction no-return-ir 124 19 1 0 0
no-return-ir/141: as byte! 66h
no-return-ir/142: as byte! 31h
no-return-ir/143: as byte! 66h
no-return-ir/144: as byte! 32h

size: x64-codegen/generate no-return-ir 144 output 1024 0
if size <= 0 [failures: failures + 1]
put no-return-ir 84 0
if (x64-codegen/generate no-return-ir 144 output 1024 0) <> x64-codegen/INVALID_IR [
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
free variadic-ir
free null-function-ir
free tagged-ir
free array-ir
free array-compare-ir
free branch-ir
free merge-ir
free selection-ir
free recursive-pointer-ir
free recursive-value-ir
free stack-ir
free log-b-ir
free system-ir
free atomic-ir
free overflow-ir
free exception-ir
free no-return-ir
either failures = 0 [
	print ["PASS: typed postfix Windows x64 codegen" lf]
][
	print ["FAIL: typed postfix x64 codegen failures=" failures lf]
]
quit failures
