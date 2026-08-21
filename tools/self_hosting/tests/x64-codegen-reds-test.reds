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
floating-entry!: alias function! [return: [float!]]
floating32-entry!: alias function! [return: [float32!]]
hidden-return-entry!: alias function! [
	result [byte-ptr!]
	value [byte-ptr!]
	return: [byte-ptr!]
]
small-return-entry!: alias function! [
	value [byte-ptr!]
	return: [byte-ptr!]
]

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

set-cast-case: func [
	data [byte-ptr!]
	source low high target keep [integer!]
][
	put data 64 target
	put-instruction data 92 1 source low high
	put-instruction data 108 8 target 0 keep
	put-instruction data 124 11 target 0 0
]

run-selection: func [
	code [byte-ptr!]
	return: [integer!]
	/local entry [selection-entry!]
][
	entry: as selection-entry! code
	entry
]

run-floating: func [
	code [byte-ptr!]
	return: [float!]
	/local entry [floating-entry!]
][
	entry: as floating-entry! code
	entry
]

run-floating32: func [
	code [byte-ptr!]
	return: [float32!]
	/local entry [floating32-entry!]
][
	entry: as floating32-entry! code
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

execute-floating?: func [
	image [byte-ptr!]
	expected [float!]
	return: [logic!]
	/local header [codegen-header!] fn [codegen-function!]
		code [byte-ptr!] result [float!]
][
	header: as codegen-header! image
	fn: as codegen-function! (image + x64-codegen/IMAGE_HEADER_SIZE)
	if header/code-size > 4096 [return false]
	code: VirtualAlloc (as byte-ptr! 0) 4096 3000h 40h
	if null? code [return false]
	copy-memory code (image + header/code-offset) header/code-size
	result: run-floating (code + fn/code-offset)
	VirtualFree code 0 8000h
	result = expected
]

execute-floating32?: func [
	image [byte-ptr!]
	expected [float32!]
	return: [logic!]
	/local header [codegen-header!] fn [codegen-function!]
		code [byte-ptr!] result [float32!]
][
	header: as codegen-header! image
	fn: as codegen-function! (image + x64-codegen/IMAGE_HEADER_SIZE)
	if header/code-size > 4096 [return false]
	code: VirtualAlloc (as byte-ptr! 0) 4096 3000h 40h
	if null? code [return false]
	copy-memory code (image + header/code-offset) header/code-size
	result: run-floating32 (code + fn/code-offset)
	VirtualFree code 0 8000h
	result = expected
]

execute-hidden-return?: func [
	image [byte-ptr!]
	return: [logic!]
	/local header [codegen-header!] fn [codegen-function!]
		code input result returned [byte-ptr!]
		entry [hidden-return-entry!] input-values result-values [int-ptr!]
		valid? [logic!]
][
	header: as codegen-header! image
	fn: as codegen-function! (image + x64-codegen/IMAGE_HEADER_SIZE
		+ x64-codegen/IMAGE_FUNCTION_SIZE)
	if header/code-size > 4096 [return false]
	code: VirtualAlloc (as byte-ptr! 0) 4096 3000h 40h
	input: allocate 16
	result: allocate 16
	if any [null? code null? input null? result][
		if not null? code [VirtualFree code 0 8000h]
		if not null? input [free input]
		if not null? result [free result]
		return false
	]
	input-values: as int-ptr! input
	input-values/1: 7
	input-values/2: 8
	input-values/3: 9
	copy-memory code (image + header/code-offset) header/code-size
	entry: as hidden-return-entry! (code + fn/code-offset)
	returned: entry result input
	result-values: as int-ptr! result
	valid?: all [
		returned = result
		result-values/1 = 70
		result-values/2 = 8
		result-values/3 = 9
	]
	VirtualFree code 0 8000h
	free input
	free result
	valid?
]

execute-small-return?: func [
	image [byte-ptr!]
	return: [logic!]
	/local header [codegen-header!] fn [codegen-function!]
		code value returned [byte-ptr!] entry [small-return-entry!] valid? [logic!]
][
	header: as codegen-header! image
	fn: as codegen-function! (image + x64-codegen/IMAGE_HEADER_SIZE)
	if header/code-size > 4096 [return false]
	code: VirtualAlloc (as byte-ptr! 0) 4096 3000h 40h
	value: allocate 8
	if any [null? code null? value][
		if not null? code [VirtualFree code 0 8000h]
		if not null? value [free value]
		return false
	]
	copy-memory code (image + header/code-offset) header/code-size
	entry: as small-return-entry! (code + fn/code-offset)
	returned: entry value
	valid?: returned = value
	VirtualFree code 0 8000h
	free value
	valid?
]

failures: 0
identity-code-size: 0
folded-code-size: 0
local-code-size: 0
branch-code-size: 0
call-branch-code-size: 0
call-drop-code-size: 0
call-float-code-size: 0
call-narrow-code-size: 0
cast-byte-code-size: 0
cast-keep-f32-code-size: 0
cast-keep-integer-code-size: 0
cast-float-width-code-size: 0
cast-integer-float-code-size: 0
call-cast-integer-code-size: 0
call-cast-float-code-size: 0
call-argument-code-size: 0
call-float-argument-code-size: 0
packed-argument-code-size: 0
widening-argument-code-size: 0
no-types: as byte-ptr! 0
sink-pairs: declare signature-pairs!
sink-pairs/memory: null
sink-pairs/pair-count: 0
sink-pairs/pair-capacity: 0
sink-pairs/slot-capacity: 0
sink-pairs/epoch: 0
if (x64-codegen/implicitly-compatible-types -3 -1 0 false
	no-types no-types 0 sink-pairs) <> 1 [
	failures: failures + 1
]
if (x64-codegen/implicitly-compatible-types -5 -2 0 false
	no-types no-types 0 sink-pairs) <> 1 [
	failures: failures + 1
]
if (x64-codegen/implicitly-compatible-types -7 -6 0 false
	no-types no-types 0 sink-pairs) <> 1 [
	failures: failures + 1
]
if (x64-codegen/implicitly-compatible-types -8 -6 0 false
	no-types no-types 0 sink-pairs) <> 1 [
	failures: failures + 1
]
if (x64-codegen/implicitly-compatible-types -1 -5 0 false
	no-types no-types 0 sink-pairs) <> 0 [
	failures: failures + 1
]
if (x64-codegen/implicitly-compatible-types -4 -1 0 false
	no-types no-types 0 sink-pairs) <> 0 [
	failures: failures + 1
]
if (x64-codegen/implicitly-compatible-types -6 -3 0 false
	no-types no-types 0 sink-pairs) <> 0 [
	failures: failures + 1
]
if (x64-codegen/implicitly-compatible-types -7 -8 0 false
	no-types no-types 0 sink-pairs) <> 0 [
	failures: failures + 1
]
output: allocate 1024
void-ir: allocate 132
local-ir: allocate 260
pointer-ir: allocate 132
index-ir: allocate 260
arithmetic-ir: allocate 260
expression-ir: allocate 260
aggregate-ir: allocate 516
abi-ir: allocate 1028
small-return-ir: allocate 180
widening-ir: allocate 676
sink-ir: allocate 676
signature-ir: allocate 1024
indirect-ir: allocate 324
variadic-ir: allocate 516
import-variadic-ir: allocate 260
null-function-ir: allocate 196
cast-ir: allocate 164
cast-flow-ir: allocate 260
static-cast-ir: allocate 180
tagged-ir: allocate 388
array-ir: allocate 260
array-compare-ir: allocate 228
branch-ir: allocate 260
call-result-ir: allocate 260
call-argument-ir: allocate 242
float-argument-ir: allocate 379
boolean-ir: allocate 260
merge-ir: allocate 260
literal-merge-ir: allocate 260
selection-ir: allocate 260
recursive-pointer-ir: allocate 164
recursive-value-ir: allocate 148
stack-ir: allocate 164
log-b-ir: allocate 132
system-ir: allocate 260
atomic-ir: allocate 276
overflow-ir: allocate 276
exception-ir: allocate 260
no-return-ir: allocate 164
header: declare codegen-header!
fn: declare codegen-function!
image-global: declare codegen-global!
array-values: as int-ptr! 0
if any [
	null? output null? void-ir null? local-ir null? pointer-ir null? index-ir
	null? arithmetic-ir
	null? expression-ir
	null? aggregate-ir null? abi-ir null? small-return-ir
	null? widening-ir null? sink-ir null? signature-ir
	null? indirect-ir null? variadic-ir
	null? import-variadic-ir null? null-function-ir null? cast-ir null? cast-flow-ir
	null? static-cast-ir
	null? tagged-ir null? array-ir null? array-compare-ir null? branch-ir
	null? call-result-ir null? boolean-ir
	null? merge-ir null? literal-merge-ir null? selection-ir
	null? recursive-pointer-ir null? recursive-value-ir
	null? stack-ir null? log-b-ir null? system-ir null? atomic-ir null? overflow-ir
	null? exception-ir null? no-return-ir
	null? call-argument-ir null? float-argument-ir
][quit 1]

; Null is implicitly compatible with reference-shaped sinks only. Keep the
; pointer and function records distinct from the built-in scalar probes.
put sink-ir 0 -6
put sink-ir 4 -5
put sink-ir 8 0
put sink-ir 12 0
put sink-ir 16 0
put sink-ir 20 -4
put sink-ir 24 0
put sink-ir 28 0
put sink-ir 32 0
put sink-ir 36 0
if (x64-codegen/implicitly-compatible-types 1 -14 0 false
	sink-ir (sink-ir + 40) 2 sink-pairs) <> 1 [
	print ["null to pointer compatibility was rejected" lf]
	failures: failures + 1
]
if (x64-codegen/implicitly-compatible-types 2 -14 0 false
	sink-ir (sink-ir + 40) 2 sink-pairs) <> 1 [
	print ["null to function compatibility was rejected" lf]
	failures: failures + 1
]
if (x64-codegen/implicitly-compatible-types -2 -14 0 false
	no-types no-types 0 sink-pairs) <> 0 [
	print ["null to byte compatibility was accepted" lf]
	failures: failures + 1
]
if (x64-codegen/implicitly-compatible-types -5 -14 0 false
	no-types no-types 0 sink-pairs) <> 0 [
	print ["null to integer compatibility was accepted" lf]
	failures: failures + 1
]
if (x64-codegen/implicitly-compatible-types -11 -14 0 false
	no-types no-types 0 sink-pairs) <> 0 [
	print ["null to logic compatibility was accepted" lf]
	failures: failures + 1
]
if (x64-codegen/implicitly-compatible-types -9 -14 0 false
	no-types no-types 0 sink-pairs) <> 0 [
	print ["null to f32 compatibility was accepted" lf]
	failures: failures + 1
]
if (x64-codegen/implicitly-compatible-types -10 -14 0 false
	no-types no-types 0 sink-pairs) <> 0 [
	print ["null to f64 compatibility was accepted" lf]
	failures: failures + 1
]

; Distinct function type records are compatible only when their ABI shape,
; return type, parameter types, and parameter flags all match.
put sink-ir 0 -4
put sink-ir 4 -11
put sink-ir 8 1
put sink-ir 12 0
put sink-ir 16 2
put sink-ir 20 -4
put sink-ir 24 -11
put sink-ir 28 1
put sink-ir 32 2
put sink-ir 36 2
put sink-ir 40 -5
put sink-ir 44 0
put sink-ir 48 -2
put sink-ir 52 0
put sink-ir 56 -5
put sink-ir 60 0
put sink-ir 64 -2
put sink-ir 68 0
if (x64-codegen/sink-compatible-types 1 2 sink-ir
	(sink-ir + 40) 2 sink-pairs) <> 1 [
	print ["equal function signatures were rejected" lf]
	failures: failures + 1
]
put sink-ir 64 -1
if (x64-codegen/sink-compatible-types 1 2 sink-ir
	(sink-ir + 40) 2 sink-pairs) <> 0 [
	print ["function parameter type mismatch was accepted" lf]
	failures: failures + 1
]
put sink-ir 64 -2
put sink-ir 8 1
put sink-ir 28 2
if (x64-codegen/sink-compatible-types 1 2 sink-ir
	(sink-ir + 40) 2 sink-pairs) <> 1 [
	print ["fixed cdecl and stdcall function signatures were incompatible" lf]
	failures: failures + 1
]
put sink-ir 8 0
if (x64-codegen/sink-compatible-types 1 2 sink-ir
	(sink-ir + 40) 2 sink-pairs) <> 1 [
	print ["default and stdcall function signatures were incompatible" lf]
	failures: failures + 1
]
put sink-ir 8 1
put sink-ir 28 9
if (x64-codegen/sink-compatible-types 1 2 sink-ir
	(sink-ir + 40) 2 sink-pairs) <> 0 [
	print ["function call shape mismatch was accepted" lf]
	failures: failures + 1
]
put sink-ir 8 8
if (x64-codegen/sink-compatible-types 1 2 sink-ir
	(sink-ir + 40) 2 sink-pairs) <> 0 [
	print ["packed and C variadic signatures were compatible" lf]
	failures: failures + 1
]
put sink-ir 8 1
put sink-ir 28 1
put sink-ir 36 1
if (x64-codegen/sink-compatible-types 1 2 sink-ir
	(sink-ir + 40) 2 sink-pairs) <> 0 [
	print ["function parameter count mismatch was accepted" lf]
	failures: failures + 1
]

; Matching recursive signatures close over the same pair of distinct records.
; Changing the recursive member on one side breaks that structural match.
put sink-ir 0 -4
put sink-ir 4 -11
put sink-ir 8 1
put sink-ir 12 0
put sink-ir 16 1
put sink-ir 20 -4
put sink-ir 24 -11
put sink-ir 28 1
put sink-ir 32 1
put sink-ir 36 1
put sink-ir 40 1
put sink-ir 44 0
put sink-ir 48 2
put sink-ir 52 0
if (x64-codegen/sink-compatible-types 1 2 sink-ir
	(sink-ir + 40) 2 sink-pairs) <> 1 [
	print ["equal recursive function signatures were rejected" lf]
	failures: failures + 1
]
put sink-ir 48 -5
if (x64-codegen/sink-compatible-types 1 2 sink-ir
	(sink-ir + 40) 2 sink-pairs) <> 0 [
	print ["recursive function member mismatch was accepted" lf]
	failures: failures + 1
]

; Eighteen distinct nested pairs force the reusable signature workspace through
; its initial 16-pair capacity and rehash every queued pair exactly once.
signature-index: 1
left-ref: 0
right-ref: 0
signature-offset: 0
while [signature-index <= 18][
	left-ref: signature-index
	right-ref: signature-index + 18
	signature-offset: (left-ref - 1) * 20
	put signature-ir signature-offset -4
	put signature-ir (signature-offset + 4) -11
	put signature-ir (signature-offset + 8) 0
	put signature-ir (signature-offset + 12) (signature-index - 1)
	put signature-ir (signature-offset + 16) 1
	signature-offset: (right-ref - 1) * 20
	put signature-ir signature-offset -4
	put signature-ir (signature-offset + 4) -11
	put signature-ir (signature-offset + 8) 0
	put signature-ir (signature-offset + 12) (signature-index + 17)
	put signature-ir (signature-offset + 16) 1
	signature-offset: 720 + ((signature-index - 1) * 8)
	put signature-ir signature-offset either signature-index = 18 [
		-5
	][signature-index + 1]
	put signature-ir (signature-offset + 4) 0
	signature-offset: 720 + ((signature-index + 17) * 8)
	put signature-ir signature-offset either signature-index = 18 [
		-5
	][signature-index + 19]
	put signature-ir (signature-offset + 4) 0
	signature-index: signature-index + 1
]
if any [
	(x64-codegen/sink-compatible-types 1 19 signature-ir
		(signature-ir + 720) 36 sink-pairs) <> 1
	sink-pairs/pair-capacity <> 32
][
	print ["nested function signature rehash failed" lf]
	failures: failures + 1
]
put signature-ir 1000 -2
if (x64-codegen/sink-compatible-types 1 19 signature-ir
	(signature-ir + 720) 36 sink-pairs) <> 0 [
	print ["nested signature mismatch was lost after rehash" lf]
	failures: failures + 1
]

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
if (x64-codegen/generate void-ir 90 output 1024 1) <> x64-codegen/UNSUPPORTED [
	failures: failures + 1
]

; fn: func [return: [integer!] /local value][value: 7 value]
; The local PLACE feeds SET directly, and its scalar result feeds DROP.
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
	local-code-size: fn/code-size
	if any [
		header/code-size <= 17
		fn/frame-size <> 64
		fn/code-size <> header/code-size
	][failures: failures + 1]
	if any [
		local-code-size <> 41
		not execute-first? output 7
	][
		print ["O0 local SET location code size: " local-code-size lf]
		failures: failures + 1
	]
]

; SET and RETURN are the declared type consumers. The frontend leaves both
; source types unchanged, so each mismatch must be rejected here independently.
put local-ir 84 -11
if (x64-codegen/generate local-ir 194 output 1024 0) <> x64-codegen/INVALID_IR [
	print ["integer SET accepted a logic source" lf]
	failures: failures + 1
]
put local-ir 84 -5
put local-ir 180 0
if (x64-codegen/generate local-ir 194 output 1024 0) <> x64-codegen/INVALID_IR [
	print ["value function accepted a void RETURN" lf]
	failures: failures + 1
]
put local-ir 180 -5

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

; A LOAD with an explicit incoming edge cannot inherit the fallthrough
; register location. Both paths must instead observe the materialized PLACE.
put local-ir 20 11
put local-ir 68 11
put-instruction local-ir 80 1 -5 7 0
put-instruction local-ir 96 3 1 1 0
put-instruction local-ir 112 5 0 0 0
put-instruction local-ir 128 12 0 0 0
put-instruction local-ir 144 3 1 1 0
put-instruction local-ir 160 1 -11 0 0
put-instruction local-ir 176 17 10 1 0
put-instruction local-ir 192 12 0 0 0
put-instruction local-ir 208 3 1 1 0
put-instruction local-ir 224 4 0 0 0
put-instruction local-ir 240 11 -5 0 0
local-ir/257: as byte! 66h
local-ir/258: as byte! 6Eh

size: x64-codegen/generate local-ir 258 output 1024 0
if any [size <= 0 not execute-first? output 7][
	print ["fallthrough address location was not materialized" lf]
	failures: failures + 1
]
put local-ir 168 1
size: x64-codegen/generate local-ir 258 output 1024 0
if any [size <= 0 not execute-first? output 7][
	print ["incoming address location was not materialized" lf]
	failures: failures + 1
]

; A direct local floating load remains in XMM0 through scalar RETURN.
put local-ir 20 7
put local-ir 44 -10
put local-ir 68 7
put local-ir 72 -10
put-instruction local-ir 80 1 -10 0 3FF80000h
put-instruction local-ir 96 3 1 1 0
put-instruction local-ir 112 5 0 0 0
put-instruction local-ir 128 12 0 0 0
put-instruction local-ir 144 3 1 1 0
put-instruction local-ir 160 4 0 0 0
put-instruction local-ir 176 11 -10 0 0
local-ir/193: as byte! 66h
local-ir/194: as byte! 6Eh

size: x64-codegen/generate local-ir 194 output 1024 0
if any [size <= 0 not execute-floating? output 1.5][
	print ["O0 XMM value location was not forwarded" lf]
	failures: failures + 1
]

; The right local LOAD stays in XMM0 until BINARY moves it to XMM1. The
; arithmetic result then stays in XMM0 through RETURN.
put local-ir 20 10
put local-ir 68 10
put-instruction local-ir 80 1 -10 0 3FF80000h
put-instruction local-ir 96 3 1 1 0
put-instruction local-ir 112 5 0 0 0
put-instruction local-ir 128 12 0 0 0
put-instruction local-ir 144 3 1 1 0
put-instruction local-ir 160 4 0 0 0
put-instruction local-ir 176 3 1 1 0
put-instruction local-ir 192 4 0 0 0
put-instruction local-ir 208 15 1 0 0
put-instruction local-ir 224 11 -10 0 0
local-ir/241: as byte! 66h
local-ir/242: as byte! 6Eh

size: x64-codegen/generate local-ir 242 output 1024 0
if size > 0 [
	fn: as codegen-function! (output + x64-codegen/IMAGE_HEADER_SIZE)
	if fn/code-size <> 76 [
		print ["O0 XMM SET/operator location code size: " fn/code-size lf]
		failures: failures + 1
	]
]
if any [size <= 0 not execute-floating? output 3.0][
	print ["O0 XMM operator location was not forwarded" lf]
	failures: failures + 1
]

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

; Dynamic INDEX consumes the original pointer and index values. A logic index
; reaches this consumer unchanged and must fail before instruction selection.
put index-ir 0 1
put index-ir 4 0
put index-ir 8 1
put index-ir 12 0
put index-ir 16 1
put index-ir 20 7
put index-ir 24 0
put index-ir 28 0
put index-ir 32 0

put index-ir 36 -6
put index-ir 40 -5
put index-ir 44 0
put index-ir 48 0
put index-ir 52 0

put index-ir 56 0
put index-ir 60 2
put index-ir 64 -5
put index-ir 68 0
put index-ir 72 0
put index-ir 76 2
put index-ir 80 2
put index-ir 84 0
put index-ir 88 7

put index-ir 92 1
put index-ir 96 0
put index-ir 100 -11
put index-ir 104 0

put-instruction index-ir 108 3 1 1 0
put-instruction index-ir 124 4 0 0 0
put-instruction index-ir 140 3 1 2 0
put-instruction index-ir 156 4 0 0 0
put-instruction index-ir 172 21 0 1 0
put-instruction index-ir 188 4 0 0 0
put-instruction index-ir 204 11 -5 0 0
index-ir/221: as byte! 66h
index-ir/222: as byte! 6Eh

if (x64-codegen/generate index-ir 222 output 1024 0) <> x64-codegen/INVALID_IR [
	print ["dynamic INDEX accepted a logic index" lf]
	failures: failures + 1
]
put index-ir 100 -5
if (x64-codegen/generate index-ir 222 output 1024 0) <= 0 [
	print ["dynamic INDEX rejected an integer index" lf]
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
	if any [
		fn/frame-size <> 48
		fn/code-size <> 57
		not execute-first? output 9
	][
		print ["O0 integer operator location code size: " fn/code-size lf]
		failures: failures + 1
	]
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

; A narrow signed right operand forwarded in EAX must be sign-extended before
; an int64 operation. Comparing the full result catches a zero-extended move.
put arithmetic-ir 20 6
put arithmetic-ir 44 -11
put arithmetic-ir 68 6
put-instruction arithmetic-ir 72 1 -7 10 0
put-instruction arithmetic-ir 88 1 -1 -1 -1
put-instruction arithmetic-ir 104 15 1 0 0
put-instruction arithmetic-ir 120 1 -7 9 0
put-instruction arithmetic-ir 136 15 13 0 0
put-instruction arithmetic-ir 152 11 -11 0 0
if any [
	(x64-codegen/generate arithmetic-ir 170 output 1024 0) <= 0
	not execute-first? output 1
][
	print ["O0 forwarded signed binary operand was not extended" lf]
	failures: failures + 1
]

; Division consumes its forwarded right operand through RCX.
put arithmetic-ir 20 4
put arithmetic-ir 44 -5
put arithmetic-ir 68 4
put-instruction arithmetic-ir 72 1 -5 8 0
put-instruction arithmetic-ir 88 1 -5 2 0
put-instruction arithmetic-ir 104 15 4 0 0
put-instruction arithmetic-ir 120 11 -5 0 0
arithmetic-ir/137: as byte! 66h
arithmetic-ir/138: as byte! 6Eh
if any [
	(x64-codegen/generate arithmetic-ir 138 output 1024 0) <= 0
	not execute-first? output 4
][
	print ["O0 forwarded division operand did not reach RCX" lf]
	failures: failures + 1
]

; Register locations are canonical values, not just untyped 32-bit payloads.
; Narrow arithmetic must truncate before its signed result widens at RETURN.
put arithmetic-ir 20 4
put arithmetic-ir 44 -7
put arithmetic-ir 68 4
put-instruction arithmetic-ir 72 1 -1 127 0
put-instruction arithmetic-ir 88 1 -1 1 0
put-instruction arithmetic-ir 104 15 1 0 0
put-instruction arithmetic-ir 120 11 -7 0 0
arithmetic-ir/137: as byte! 66h
arithmetic-ir/138: as byte! 6Eh
if any [
	(x64-codegen/generate arithmetic-ir 138 output 1024 0) <= 0
	not execute-first? output -128
][
	print ["O0 signed narrow binary result was not canonical" lf]
	failures: failures + 1
]

; Unsigned NOT likewise keeps only its declared byte before widening.
put arithmetic-ir 20 3
put arithmetic-ir 68 3
put-instruction arithmetic-ir 72 1 -2 1 0
put-instruction arithmetic-ir 88 14 1 0 0
put-instruction arithmetic-ir 104 11 -7 0 0
arithmetic-ir/121: as byte! 66h
arithmetic-ir/122: as byte! 6Eh
if any [
	(x64-codegen/generate arithmetic-ir 122 output 1024 0) <= 0
	not execute-first? output 254
][
	print ["O0 unsigned narrow unary result was not canonical" lf]
	failures: failures + 1
]

; Scalar operator legality and result types are owned by native codegen.
; fn: func [return: [float!]][1.0 + 2.0]
put expression-ir 0 1
put expression-ir 4 0
put expression-ir 8 0
put expression-ir 12 0
put expression-ir 16 1
put expression-ir 20 4
put expression-ir 24 0
put expression-ir 28 0
put expression-ir 32 0
put expression-ir 36 0
put expression-ir 40 2
put expression-ir 44 -10
put expression-ir 48 0
put expression-ir 52 0
put expression-ir 56 0
put expression-ir 60 0
put expression-ir 64 0
put expression-ir 68 4
put-instruction expression-ir 72 1 -10 0 1072693248
put-instruction expression-ir 88 1 -10 0 1073741824
put-instruction expression-ir 104 15 1 0 0
put-instruction expression-ir 120 11 -10 0 0
expression-ir/137: as byte! 66h
expression-ir/138: as byte! 6Eh

if (x64-codegen/generate expression-ir 138 output 1024 0) <= 0 [
	print ["expression f64 arithmetic failed" lf]
	failures: failures + 1
]

; Arithmetic follows the existing common-float rule: either float32! operand
; selects float32! machine operations and a float32! result.
put expression-ir 92 -9
put expression-ir 96 40000000h
put expression-ir 44 -9
put expression-ir 124 -9
if (x64-codegen/generate expression-ir 138 output 1024 0) <= 0 [
	print ["expression mixed f64/f32 arithmetic failed" lf]
	failures: failures + 1
]

; Comparisons still require matching floating-point types.
put expression-ir 108 13
put expression-ir 44 -11
put expression-ir 124 -11
if (x64-codegen/generate expression-ir 138 output 1024 0)
	<> x64-codegen/INVALID_IR [
	print ["expression mixed float comparison was accepted" lf]
	failures: failures + 1
]

; Reversing the widths retains the same float32! common result.
put expression-ir 76 -9
put expression-ir 80 3F800000h
put expression-ir 92 -10
put expression-ir 96 0
put expression-ir 100 1073741824
put expression-ir 108 1
put expression-ir 44 -9
put expression-ir 124 -9
if (x64-codegen/generate expression-ir 138 output 1024 0) <= 0 [
	print ["expression mixed f32/f64 arithmetic failed" lf]
	failures: failures + 1
]

; Execute both mixed orders with values that distinguish conversion before the
; operation from conversion after it.
put expression-ir 20 6
put expression-ir 44 -11
put expression-ir 68 6
put-instruction expression-ir 72 1 -10 10000000h 41700000h
put-instruction expression-ir 88 1 -9 CB800000h 0
put-instruction expression-ir 104 15 1 0 0
put-instruction expression-ir 120 1 -9 0 0
put-instruction expression-ir 136 15 13 0 0
put-instruction expression-ir 152 11 -11 0 0
expression-ir/169: as byte! 66h
expression-ir/170: as byte! 6Eh
size: x64-codegen/generate expression-ir 170 output 1024 0
if any [size <= 0 not execute-first? output 1][
	print ["expression mixed f64/f32 conversion failed" lf]
	failures: failures + 1
]

put-instruction expression-ir 72 1 -9 CB800000h 0
put-instruction expression-ir 88 1 -10 10000000h 41700000h
size: x64-codegen/generate expression-ir 170 output 1024 0
if any [size <= 0 not execute-first? output 1][
	print ["expression mixed f32/f64 conversion failed" lf]
	failures: failures + 1
]

; float! does not support remainder or modulo.
put expression-ir 20 4
put expression-ir 44 -10
put expression-ir 68 4
put-instruction expression-ir 72 1 -10 0 1072693248
put-instruction expression-ir 88 1 -10 0 1073741824
put-instruction expression-ir 104 15 6 0 0
put-instruction expression-ir 120 11 -10 0 0
expression-ir/137: as byte! 66h
expression-ir/138: as byte! 6Eh
if (x64-codegen/generate expression-ir 138 output 1024 0)
	<> x64-codegen/INVALID_IR [
	print ["expression float modulo was accepted" lf]
	failures: failures + 1
]

; Reuse the module for NOT: integer and logic are valid, float is not.
put expression-ir 20 3
put expression-ir 44 -5
put expression-ir 68 3
put-instruction expression-ir 72 1 -5 1 0
put-instruction expression-ir 88 14 1 0 0
put-instruction expression-ir 104 11 -5 0 0
expression-ir/121: as byte! 66h
expression-ir/122: as byte! 6Eh
size: x64-codegen/generate expression-ir 122 output 1024 0
if any [size <= 0 not execute-first? output -2][
	print ["expression integer NOT failed" lf]
	failures: failures + 1
]
if size > 0 [
	fn: as codegen-function! (output + x64-codegen/IMAGE_HEADER_SIZE)
	if fn/code-size <> 28 [
		print ["O0 unary operator location code size: " fn/code-size lf]
		failures: failures + 1
	]
]
put expression-ir 76 -11
put expression-ir 44 -11
put expression-ir 108 -11
size: x64-codegen/generate expression-ir 122 output 1024 0
if any [size <= 0 not execute-first? output 0][
	print ["expression logic NOT failed" lf]
	failures: failures + 1
]
put expression-ir 76 -10
put expression-ir 44 -10
put expression-ir 108 -10
if (x64-codegen/generate expression-ir 122 output 1024 0)
	<> x64-codegen/INVALID_IR [
	print ["expression float NOT was accepted" lf]
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
	unless execute-hidden-return? output [
		print ["hidden aggregate RETURN lost its buffer result" lf]
		failures: failures + 1
	]
]

; An eight-byte aggregate returns directly in RAX. Calling the generated
; function with pointer-shaped bits makes the exact result easy to distinguish
; from the address of its compiler stack slot.
put small-return-ir 0 1
put small-return-ir 4 0
put small-return-ir 8 1
put small-return-ir 12 0
put small-return-ir 16 1
put small-return-ir 20 3
put small-return-ir 24 0
put small-return-ir 28 0
put small-return-ir 32 0

put small-return-ir 36 -2
put small-return-ir 40 0
put small-return-ir 44 0
put small-return-ir 48 0
put small-return-ir 52 2
put small-return-ir 56 -5
put small-return-ir 60 0
put small-return-ir 64 -5
put small-return-ir 68 0

put small-return-ir 72 0
put small-return-ir 76 2
put small-return-ir 80 1
put small-return-ir 84 x64-codegen/RETURN_VALUE
put small-return-ir 88 0
put small-return-ir 92 1
put small-return-ir 96 1
put small-return-ir 100 0
put small-return-ir 104 3

put small-return-ir 108 1
put small-return-ir 112 x64-codegen/INLINE
put-instruction small-return-ir 116 3 1 1 0
put-instruction small-return-ir 132 4 0 0 0
put-instruction small-return-ir 148 11 1 0 0
small-return-ir/165: as byte! 66h
small-return-ir/166: as byte! 6Eh

size: x64-codegen/generate small-return-ir 166 output 1024 0
if any [size <= 0 not execute-small-return? output][
	print ["register aggregate RETURN lost its value" lf]
	failures: failures + 1
]

; One module exercises every implicit integer widening consumer. The entry
; combines SUB_RETURN, fixed CALL arguments, SET, ordinary RETURN, and a mixed
; integer comparison into the expected logic result.
put widening-ir 0 1
put widening-ir 4 0
put widening-ir 8 0
put widening-ir 12 0
put widening-ir 16 3
put widening-ir 20 30
put widening-ir 24 0
put widening-ir 28 0
put widening-ir 32 0

put widening-ir 36 0
put widening-ir 40 1
put widening-ir 44 -11
put widening-ir 48 0
put widening-ir 52 0
put widening-ir 56 0
put widening-ir 60 0
put widening-ir 64 1
put widening-ir 68 22

put widening-ir 72 0
put widening-ir 76 1
put widening-ir 80 -7
put widening-ir 84 0
put widening-ir 88 1
put widening-ir 92 5
put widening-ir 96 6
put widening-ir 100 0
put widening-ir 104 6

put widening-ir 108 0
put widening-ir 112 1
put widening-ir 116 -7
put widening-ir 120 0
put widening-ir 124 6
put widening-ir 128 0
put widening-ir 132 6
put widening-ir 136 0
put widening-ir 140 2

put widening-ir 144 -7
put widening-ir 148 0
put widening-ir 152 -7
put widening-ir 156 0
put widening-ir 160 -7
put widening-ir 164 0
put widening-ir 168 -7
put widening-ir 172 0
put widening-ir 176 -7
put widening-ir 180 0
put widening-ir 184 -7
put widening-ir 188 0

; Function 1 starts with a local subroutine so its entry jumps over the body.
put-instruction widening-ir 192 16 5 0 0
put-instruction widening-ir 208 27 1 -7 0
put-instruction widening-ir 224 1 -1 -2 -1
put-instruction widening-ir 240 29 -7 0 0
put-instruction widening-ir 256 27 0 0 0
put-instruction widening-ir 272 28 2 -7 0

; The first fixed argument widens in a register; the fifth widens from the
; caller's stack slot. The callee returns their sum, -2 + 250 = 248.
put-instruction widening-ir 288 1 -1 -2 -1
put-instruction widening-ir 304 1 -7 0 0
put-instruction widening-ir 320 1 -7 0 0
put-instruction widening-ir 336 1 -7 0 0
put-instruction widening-ir 352 1 -2 250 0
put-instruction widening-ir 368 7 2 5 -7
put-instruction widening-ir 384 15 1 0 0

; SET widens signed int8 -3 into the int64 local.
put-instruction widening-ir 400 1 -1 -3 -1
put-instruction widening-ir 416 3 1 1 0
put-instruction widening-ir 432 5 0 0 0
put-instruction widening-ir 448 15 1 0 0

; Add an ordinary widened return (-4), then compare the total 239 against a
; uint16 literal to exercise mixed signed/unsigned equality.
put-instruction widening-ir 464 7 3 0 -7
put-instruction widening-ir 480 15 1 0 0
put-instruction widening-ir 496 1 -4 239 0
put-instruction widening-ir 512 15 13 0 0
put-instruction widening-ir 528 11 -11 0 0

; Function 2 returns its first and fifth fixed parameters.
put-instruction widening-ir 544 3 1 1 0
put-instruction widening-ir 560 4 0 0 0
put-instruction widening-ir 576 3 1 5 0
put-instruction widening-ir 592 4 0 0 0
put-instruction widening-ir 608 15 1 0 0
put-instruction widening-ir 624 11 -7 0 0

; Function 3 widens an int8 literal at an ordinary RETURN.
put-instruction widening-ir 640 1 -1 -4 -1
put-instruction widening-ir 656 11 -7 0 0
widening-ir/673: as byte! 66h

size: x64-codegen/generate widening-ir 673 output 1024 0
if size <= 0 [failures: failures + 1]
if size > 0 [
	header: as codegen-header! output
	if header/function-count <> 3 [failures: failures + 1]
	fn: as codegen-function! (output + x64-codegen/IMAGE_HEADER_SIZE)
	widening-argument-code-size: fn/code-size
	if widening-argument-code-size <> 231 [
		print ["O0 fifth argument code size: " widening-argument-code-size lf]
		failures: failures + 1
	]
	unless execute-first? output 1 [failures: failures + 1]
]

; A fixed parameter rejects narrowing from int64 to int8.
put widening-ir 152 -1
put widening-ir 292 -7
if (x64-codegen/generate widening-ir 673 output 1024 0) <> x64-codegen/INVALID_IR [
	failures: failures + 1
]
put widening-ir 152 -7
put widening-ir 292 -1

; SET rejects a signed source when the destination is unsigned.
put widening-ir 144 -8
put widening-ir 448 12
put widening-ir 452 0
if (x64-codegen/generate widening-ir 673 output 1024 0) <> x64-codegen/INVALID_IR [
	failures: failures + 1
]
put widening-ir 144 -7
put widening-ir 448 15
put widening-ir 452 1

; An ordinary RETURN rejects narrowing after its caller metadata is adjusted
; to keep the rest of the module internally consistent.
put widening-ir 116 -1
put widening-ir 476 -1
put widening-ir 644 -7
put widening-ir 660 -1
if (x64-codegen/generate widening-ir 673 output 1024 0) <> x64-codegen/INVALID_IR [
	failures: failures + 1
]
put widening-ir 116 -7
put widening-ir 476 -7
put widening-ir 644 -1
put widening-ir 660 -7

; Equal-width signed and unsigned integers have no lossless common type.
put widening-ir 500 -8
if (x64-codegen/generate widening-ir 673 output 1024 0) <> x64-codegen/INVALID_IR [
	failures: failures + 1
]
put widening-ir 500 -4

; A direct binary64 literal may narrow at a fixed binary32 CALL. The chosen
; value rounds from 16777217.0 to 16777216.0, so execution also proves that
; codegen converts the value rather than merely accepting its type.
put sink-ir 0 1
put sink-ir 4 0
put sink-ir 8 0
put sink-ir 12 0
put sink-ir 16 2
put sink-ir 20 8
put sink-ir 24 0
put sink-ir 28 0
put sink-ir 32 0

put sink-ir 36 0
put sink-ir 40 4
put sink-ir 44 -11
put sink-ir 48 0
put sink-ir 52 0
put sink-ir 56 0
put sink-ir 60 0
put sink-ir 64 0
put sink-ir 68 5

put sink-ir 72 4
put sink-ir 76 4
put sink-ir 80 -9
put sink-ir 84 0
put sink-ir 88 0
put sink-ir 92 1
put sink-ir 96 1
put sink-ir 100 0
put sink-ir 104 3

put sink-ir 108 -9
put sink-ir 112 0

put-instruction sink-ir 116 1 -10 10000000h 41700000h
put-instruction sink-ir 132 7 2 1 -9
put-instruction sink-ir 148 1 -9 4B800000h 0
put-instruction sink-ir 164 15 13 0 0
put-instruction sink-ir 180 11 -11 0 0

put-instruction sink-ir 196 3 1 1 0
put-instruction sink-ir 212 4 0 0 0
put-instruction sink-ir 228 11 -9 0 0
sink-ir/245: as byte! 6Dh
sink-ir/246: as byte! 61h
sink-ir/247: as byte! 69h
sink-ir/248: as byte! 6Eh
sink-ir/249: as byte! 74h
sink-ir/250: as byte! 61h
sink-ir/251: as byte! 6Bh
sink-ir/252: as byte! 65h

size: x64-codegen/generate sink-ir 252 output 1024 0
if any [size <= 0 not execute-first? output 1][
	print ["literal f64 to fixed f32 CALL failed" lf]
	failures: failures + 1
]

; CUSTOM consumes one ordinary stack value as its dynamic argument count.
; The frontend does not pre-coerce it; native CALL must reject a non-integer.
put sink-ir 84 32
if (x64-codegen/generate sink-ir 252 output 1024 0) <> x64-codegen/INVALID_IR [
	print ["non-integer custom call count was accepted" lf]
	failures: failures + 1
]
put sink-ir 84 0

; The same binary64 value is not allowed to narrow at an ordinary RETURN.
; Widening the callee parameter makes its LOAD produce a runtime binary64.
put sink-ir 108 -10
if (x64-codegen/generate sink-ir 252 output 1024 0) <> x64-codegen/INVALID_IR [
	print ["runtime f64 to f32 RETURN was accepted" lf]
	failures: failures + 1
]
put sink-ir 108 -9

; LOAD clears the direct-literal trait, so a runtime binary64 cannot narrow at
; the otherwise literal-aware fixed binary32 CALL.
put sink-ir 20 7
put sink-ir 44 -9
put sink-ir 64 1
put sink-ir 68 4
put sink-ir 80 -9
put sink-ir 88 1
put sink-ir 92 1
put sink-ir 96 2
put sink-ir 100 0
put sink-ir 104 3
put sink-ir 108 -10
put sink-ir 112 0
put sink-ir 116 -9
put sink-ir 120 0
put-instruction sink-ir 124 3 1 1 0
put-instruction sink-ir 140 4 0 0 0
put-instruction sink-ir 156 7 2 1 -9
put-instruction sink-ir 172 11 -9 0 0
put-instruction sink-ir 188 3 1 1 0
put-instruction sink-ir 204 4 0 0 0
put-instruction sink-ir 220 11 -9 0 0
sink-ir/237: as byte! 6Dh
sink-ir/238: as byte! 61h
sink-ir/239: as byte! 69h
sink-ir/240: as byte! 6Eh
sink-ir/241: as byte! 74h
sink-ir/242: as byte! 61h
sink-ir/243: as byte! 6Bh
sink-ir/244: as byte! 65h

if (x64-codegen/generate sink-ir 244 output 1024 0) <> x64-codegen/INVALID_IR [
	print ["loaded f64 to fixed f32 CALL was accepted" lf]
	failures: failures + 1
]
put sink-ir 108 -9
if (x64-codegen/generate sink-ir 244 output 1024 0) <= 0 [
	print ["matched loaded f32 CALL control failed" lf]
	failures: failures + 1
]

; SET is not a literal-aware sink and rejects binary64-to-binary32 narrowing.
put sink-ir 116 -9
put-instruction sink-ir 124 1 -10 0 1073217536
put-instruction sink-ir 140 3 1 1 0
put-instruction sink-ir 156 5 0 0 0
put-instruction sink-ir 172 11 -9 0 0
if (x64-codegen/generate sink-ir 244 output 1024 0) <> x64-codegen/INVALID_IR [
	print ["literal f64 to f32 SET was accepted" lf]
	failures: failures + 1
]

; Contextual null stays typeless in RSIR. Scalar CALL, SET, and RETURN sinks
; reject it without changing any of the three source tags.
put sink-ir 20 9
put sink-ir 44 -11
put sink-ir 64 1
put sink-ir 68 7
put sink-ir 80 -9
put sink-ir 88 1
put sink-ir 92 1
put sink-ir 96 2
put sink-ir 100 0
put sink-ir 104 2
put sink-ir 108 -9
put sink-ir 112 0
put sink-ir 116 -9
put sink-ir 120 0
put-instruction sink-ir 124 1 -14 0 0
put-instruction sink-ir 140 7 2 1 -9
put-instruction sink-ir 156 1 -14 0 0
put-instruction sink-ir 172 3 1 1 0
put-instruction sink-ir 188 5 0 0 0
put-instruction sink-ir 204 15 13 0 0
put-instruction sink-ir 220 11 -11 0 0
put-instruction sink-ir 236 1 -14 0 0
put-instruction sink-ir 252 11 -9 0 0
sink-ir/269: as byte! 6Dh
sink-ir/270: as byte! 61h
sink-ir/271: as byte! 69h
sink-ir/272: as byte! 6Eh
sink-ir/273: as byte! 73h
sink-ir/274: as byte! 69h
sink-ir/275: as byte! 6Eh
sink-ir/276: as byte! 6Bh

array-values: as int-ptr! sink-ir
if any [
	array-values/33 <> -14
	array-values/41 <> -14
	array-values/61 <> -14
][
	print ["contextual null was retagged in RSIR" lf]
	failures: failures + 1
]
if (x64-codegen/generate sink-ir 276 output 1024 0) <> x64-codegen/INVALID_IR [
	print ["contextual null scalar CALL was accepted" lf]
	failures: failures + 1
]
put sink-ir 128 -9
if (x64-codegen/generate sink-ir 276 output 1024 0) <> x64-codegen/INVALID_IR [
	print ["contextual null scalar SET was accepted" lf]
	failures: failures + 1
]
put sink-ir 160 -9
if (x64-codegen/generate sink-ir 276 output 1024 0) <> x64-codegen/INVALID_IR [
	print ["contextual null scalar RETURN was accepted" lf]
	failures: failures + 1
]
put sink-ir 240 -9
if (x64-codegen/generate sink-ir 276 output 1024 0) <= 0 [
	print ["matched scalar null-sink control failed" lf]
	failures: failures + 1
]

; Fixed cdecl/default/stdcall function values share the Win64 ABI. Packed and
; C variadic signatures remain distinct at SET, fixed CALL, and RETURN sinks.
put sink-ir 0 1
put sink-ir 4 0
put sink-ir 8 2
put sink-ir 12 0
put sink-ir 16 3
put sink-ir 20 13
put sink-ir 24 0
put sink-ir 28 0
put sink-ir 32 0

put sink-ir 36 -4
put sink-ir 40 0
put sink-ir 44 0
put sink-ir 48 0
put sink-ir 52 0
put sink-ir 56 -4
put sink-ir 60 0
put sink-ir 64 2
put sink-ir 68 0
put sink-ir 72 0

put sink-ir 76 0
put sink-ir 80 1
put sink-ir 84 0
put sink-ir 88 0
put sink-ir 92 0
put sink-ir 96 0
put sink-ir 100 0
put sink-ir 104 0
put sink-ir 108 1

put sink-ir 112 0
put sink-ir 116 1
put sink-ir 120 0
put sink-ir 124 0
put sink-ir 128 0
put sink-ir 132 1
put sink-ir 136 1
put sink-ir 140 0
put sink-ir 144 1

put sink-ir 148 0
put sink-ir 152 1
put sink-ir 156 2
put sink-ir 160 0
put sink-ir 164 1
put sink-ir 168 0
put sink-ir 172 1
put sink-ir 176 1
put sink-ir 180 11

put sink-ir 184 2
put sink-ir 188 0
put sink-ir 192 2
put sink-ir 196 0

put-instruction sink-ir 200 11 0 0 0
put-instruction sink-ir 216 11 0 0 0
put-instruction sink-ir 232 3 4 1 1
put-instruction sink-ir 248 20 1 0 0
put-instruction sink-ir 264 3 1 1 0
put-instruction sink-ir 280 5 0 0 0
put-instruction sink-ir 296 12 0 0 0
put-instruction sink-ir 312 3 4 1 1
put-instruction sink-ir 328 20 1 0 0
put-instruction sink-ir 344 7 2 1 0
put-instruction sink-ir 360 3 4 1 1
put-instruction sink-ir 376 20 1 0 0
put-instruction sink-ir 392 11 2 0 0
sink-ir/409: as byte! 0

if (x64-codegen/generate sink-ir 409 output 1024 0) <= 0 [
	print ["default and stdcall function sinks were incompatible" lf]
	failures: failures + 1
]
put sink-ir 44 1
put sink-ir 88 1
if (x64-codegen/generate sink-ir 409 output 1024 0) <= 0 [
	print ["fixed cdecl function sinks were incompatible" lf]
	failures: failures + 1
]

; Type 1 is C variadic while type 2 is the packed Red/System variadic shape.
; Give SET the exact source type after its isolated rejection, then do the
; same for CALL so each sink is reached independently.
put sink-ir 44 9
put sink-ir 64 8
if (x64-codegen/generate sink-ir 409 output 1024 0) <> x64-codegen/INVALID_IR [
	print ["C variadic function value entered a packed SET sink" lf]
	failures: failures + 1
]
put sink-ir 192 1
if (x64-codegen/generate sink-ir 409 output 1024 0) <> x64-codegen/INVALID_IR [
	print ["C variadic function value entered a packed CALL sink" lf]
	failures: failures + 1
]
put sink-ir 184 1
if (x64-codegen/generate sink-ir 409 output 1024 0) <> x64-codegen/INVALID_IR [
	print ["C variadic function value entered a packed RETURN sink" lf]
	failures: failures + 1
]

; CDECL variadic extras apply the default binary32-to-binary64 promotion in
; codegen. The fifth argument uses a Win64 stack slot, and the concrete callee
; consumes that slot as binary64, making this an executable conversion check.
put sink-ir 0 1
put sink-ir 4 0
put sink-ir 8 2
put sink-ir 12 0
put sink-ir 16 2
put sink-ir 20 15
put sink-ir 24 0
put sink-ir 28 0
put sink-ir 32 0

put sink-ir 36 -4
put sink-ir 40 -10
put sink-ir 44 9
put sink-ir 48 0
put sink-ir 52 1
put sink-ir 56 -4
put sink-ir 60 -10
put sink-ir 64 1
put sink-ir 68 1
put sink-ir 72 5

put sink-ir 76 -5
put sink-ir 80 0
put sink-ir 84 -5
put sink-ir 88 0
put sink-ir 92 -5
put sink-ir 96 0
put sink-ir 100 -5
put sink-ir 104 0
put sink-ir 108 -5
put sink-ir 112 0
put sink-ir 116 -10
put sink-ir 120 0

put sink-ir 124 0
put sink-ir 128 4
put sink-ir 132 -11
put sink-ir 136 0
put sink-ir 140 0
put sink-ir 144 0
put sink-ir 148 0
put sink-ir 152 0
put sink-ir 156 12

put sink-ir 160 4
put sink-ir 164 9
put sink-ir 168 -10
put sink-ir 172 1
put sink-ir 176 0
put sink-ir 180 5
put sink-ir 184 5
put sink-ir 188 0
put sink-ir 192 3

put sink-ir 196 -5
put sink-ir 200 0
put sink-ir 204 -5
put sink-ir 208 0
put sink-ir 212 -5
put sink-ir 216 0
put sink-ir 220 -5
put sink-ir 224 0
put sink-ir 228 -10
put sink-ir 232 0

put-instruction sink-ir 236 3 4 2 2
put-instruction sink-ir 252 20 2 0 0
put-instruction sink-ir 268 8 1 0 0
put-instruction sink-ir 284 1 -5 0 0
put-instruction sink-ir 300 1 -5 0 0
put-instruction sink-ir 316 1 -5 0 0
put-instruction sink-ir 332 1 -5 0 0
put-instruction sink-ir 348 1 -9 3FC00000h 0
put-instruction sink-ir 364 7 0 5 1
put-instruction sink-ir 380 1 -10 0 1073217536
put-instruction sink-ir 396 15 13 0 0
put-instruction sink-ir 412 11 -11 0 0

put-instruction sink-ir 428 3 1 5 0
put-instruction sink-ir 444 4 0 0 0
put-instruction sink-ir 460 11 -10 0 0
sink-ir/477: as byte! 6Dh
sink-ir/478: as byte! 61h
sink-ir/479: as byte! 69h
sink-ir/480: as byte! 6Eh
sink-ir/481: as byte! 72h
sink-ir/482: as byte! 65h
sink-ir/483: as byte! 61h
sink-ir/484: as byte! 64h
sink-ir/485: as byte! 2Dh
sink-ir/486: as byte! 66h
sink-ir/487: as byte! 69h
sink-ir/488: as byte! 76h
sink-ir/489: as byte! 65h

size: x64-codegen/generate sink-ir 489 output 1024 0
if any [size <= 0 not execute-first? output 1][
	print ["cdecl variadic stack f32 promotion failed" lf]
	failures: failures + 1
]

; A register-slot CDECL variadic extra is promoted in XMM1 and its converted
; binary64 bits are mirrored in RDX. The callee checks both channels against
; 1.5 before any body instruction can overwrite RDX.
put sink-ir 0 1
put sink-ir 4 0
put sink-ir 8 4
put sink-ir 12 0
put sink-ir 16 2
put sink-ir 20 23
put sink-ir 24 0
put sink-ir 28 0
put sink-ir 32 0

put sink-ir 36 -4
put sink-ir 40 -11
put sink-ir 44 9
put sink-ir 48 0
put sink-ir 52 1

put sink-ir 56 -4
put sink-ir 60 -11
put sink-ir 64 1
put sink-ir 68 1
put sink-ir 72 2

put sink-ir 76 -6
put sink-ir 80 -5
put sink-ir 84 0
put sink-ir 88 3
put sink-ir 92 0

put sink-ir 96 -6
put sink-ir 100 -10
put sink-ir 104 0
put sink-ir 108 3
put sink-ir 112 0

put sink-ir 116 -5
put sink-ir 120 0
put sink-ir 124 -5
put sink-ir 128 0
put sink-ir 132 -10
put sink-ir 136 0

put sink-ir 140 0
put sink-ir 144 1
put sink-ir 148 -11
put sink-ir 152 0
put sink-ir 156 0
put sink-ir 160 0
put sink-ir 164 0
put sink-ir 168 0
put sink-ir 172 7

put sink-ir 176 1
put sink-ir 180 1
put sink-ir 184 -11
put sink-ir 188 1
put sink-ir 192 0
put sink-ir 196 2
put sink-ir 200 2
put sink-ir 204 1
put sink-ir 208 16

put sink-ir 212 -5
put sink-ir 216 0
put sink-ir 220 -10
put sink-ir 224 0
put sink-ir 228 3
put sink-ir 232 0

put-instruction sink-ir 236 3 4 2 2
put-instruction sink-ir 252 20 2 0 0
put-instruction sink-ir 268 8 1 0 0
put-instruction sink-ir 284 1 -5 0 0
put-instruction sink-ir 300 1 -9 3FC00000h 0
put-instruction sink-ir 316 7 0 2 1
put-instruction sink-ir 332 11 -11 0 0

put-instruction sink-ir 348 10 14 2 3
put-instruction sink-ir 364 3 1 3 0
put-instruction sink-ir 380 5 0 0 0
put-instruction sink-ir 396 12 0 0 0
put-instruction sink-ir 412 3 1 3 0
put-instruction sink-ir 428 20 4 0 0
put-instruction sink-ir 444 21 0 0 0
put-instruction sink-ir 460 4 0 0 0
put-instruction sink-ir 476 1 -10 0 1073217536
put-instruction sink-ir 492 15 13 0 0
put-instruction sink-ir 508 3 1 2 0
put-instruction sink-ir 524 4 0 0 0
put-instruction sink-ir 540 1 -10 0 1073217536
put-instruction sink-ir 556 15 13 0 0
put-instruction sink-ir 572 15 12 0 0
put-instruction sink-ir 588 11 -11 0 0
sink-ir/605: as byte! 61h
sink-ir/606: as byte! 62h
sink-ir/607: as byte! 72h
sink-ir/608: as byte! 64h
sink-ir/609: as byte! 78h

size: x64-codegen/generate sink-ir 609 output 1024 0
if any [size <= 0 not execute-first? output 1][
	print ["cdecl variadic register f32 promotion or GPR mirror failed" lf]
	failures: failures + 1
]

; A tagged-union PLACE keeps its variant write chain in stack-tags. LOAD must
; retain that index when it becomes a VALUE, but a positive variant index is
; not the negative direct-literal tag and cannot narrow at the following CALL.
put sink-ir 0 1
put sink-ir 4 0
put sink-ir 8 1
put sink-ir 12 0
put sink-ir 16 2
put sink-ir 20 7
put sink-ir 24 0
put sink-ir 28 0
put sink-ir 32 0

put sink-ir 36 -3
put sink-ir 40 0
put sink-ir 44 1
put sink-ir 48 0
put sink-ir 52 1
put sink-ir 56 -10
put sink-ir 60 0

put sink-ir 64 0
put sink-ir 68 1
put sink-ir 72 0
put sink-ir 76 0
put sink-ir 80 0
put sink-ir 84 0
put sink-ir 88 0
put sink-ir 92 1
put sink-ir 96 6

put sink-ir 100 1
put sink-ir 104 1
put sink-ir 108 0
put sink-ir 112 0
put sink-ir 116 1
put sink-ir 120 1
put sink-ir 124 0
put sink-ir 128 0
put sink-ir 132 1

put sink-ir 136 1
put sink-ir 140 1
put sink-ir 144 -9
put sink-ir 148 0

put-instruction sink-ir 152 16 2 0 0
put-instruction sink-ir 168 3 1 1 0
put-instruction sink-ir 184 6 0 1 0
put-instruction sink-ir 200 4 0 0 0
put-instruction sink-ir 216 7 2 1 0
put-instruction sink-ir 232 11 0 0 0
put-instruction sink-ir 248 11 0 0 0
sink-ir/265: as byte! 61h
sink-ir/266: as byte! 62h

if (x64-codegen/generate sink-ir 266 output 1024 0) <> x64-codegen/INVALID_IR [
	print ["tagged member LOAD confused a variant chain with a literal tag" lf]
	failures: failures + 1
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

; Callable type records reject catch mode combined with a foreign convention.
; This validates raw function/subroutine types, not rsir-function! flags.
put indirect-ir 44 (x64-codegen/CATCH_FLAG + x64-codegen/CDECL)
if (x64-codegen/generate indirect-ir 306 output 1024 0) <> x64-codegen/INVALID_IR [
	print ["conflicting raw function type flags were accepted" lf]
	failures: failures + 1
]
put indirect-ir 36 -5
if (x64-codegen/generate indirect-ir 306 output 1024 0) <> x64-codegen/INVALID_IR [
	print ["conflicting raw subroutine type flags were accepted" lf]
	failures: failures + 1
]
put indirect-ir 36 -4
put indirect-ir 44 0

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
	fn: as codegen-function! (output + x64-codegen/IMAGE_HEADER_SIZE)
	packed-argument-code-size: fn/code-size
	if packed-argument-code-size <> 74 [
		print ["O0 packed argument code size: " packed-argument-code-size lf]
		failures: failures + 1
	]
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

; Contextual null conversion belongs to SET/CALL/RETURN. An explicit OP_CAST
; cannot give typeless NULL a declared type.
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
if size <> x64-codegen/INVALID_IR [
	print ["explicit null function cast was accepted" lf]
	failures: failures + 1
]

; Dynamic cast legality is owned by OP_CAST. One function type plus three
; instructions are enough to exercise the complete scalar/reference matrix.
put cast-ir 0 1
put cast-ir 4 0
put cast-ir 8 1
put cast-ir 12 0
put cast-ir 16 1
put cast-ir 20 3
put cast-ir 24 0
put cast-ir 28 0
put cast-ir 32 0

put cast-ir 36 -4
put cast-ir 40 -5
put cast-ir 44 0
put cast-ir 48 0
put cast-ir 52 0

put cast-ir 56 0
put cast-ir 60 1
put cast-ir 64 -5
put cast-ir 68 0
put cast-ir 72 0
put cast-ir 76 0
put cast-ir 80 0
put cast-ir 84 0
put cast-ir 88 3
cast-ir/141: as byte! 63h

set-cast-case cast-ir 1 0 0 -5 0
size: x64-codegen/generate cast-ir 141 output 1024 0
if any [size <= 0 not execute-first? output 0][
	print ["function-to-integer cast was rejected" lf]
	failures: failures + 1
]

set-cast-case cast-ir 1 0 0 -15 0
if (x64-codegen/generate cast-ir 141 output 1024 0) <> x64-codegen/INVALID_IR [
	print ["function-to-byte cast was accepted" lf]
	failures: failures + 1
]

set-cast-case cast-ir -5 257 0 -15 0
size: x64-codegen/generate cast-ir 141 output 1024 0
if any [size <= 0 not execute-first? output 1][
	print ["integer-to-byte cast failed" lf]
	failures: failures + 1
]
if size > 0 [
	fn: as codegen-function! (output + x64-codegen/IMAGE_HEADER_SIZE)
	cast-byte-code-size: fn/code-size
	if cast-byte-code-size <> 29 [
		print ["O0 integer-to-byte CAST code size: " cast-byte-code-size lf]
		failures: failures + 1
	]
]

set-cast-case cast-ir -12 0 0 -11 0
size: x64-codegen/generate cast-ir 141 output 1024 0
if any [size <= 0 not execute-first? output 0][
	print ["pointer-to-logic cast failed" lf]
	failures: failures + 1
]

set-cast-case cast-ir -5 1069547520 0 -9 1
size: x64-codegen/generate cast-ir 141 output 1024 0
if any [size <= 0 not execute-floating32? output 1.5][
	print ["bit-preserving integer-to-float32 cast was rejected" lf]
	failures: failures + 1
]
if size > 0 [
	fn: as codegen-function! (output + x64-codegen/IMAGE_HEADER_SIZE)
	cast-keep-f32-code-size: fn/code-size
	if cast-keep-f32-code-size <> 30 [
		print ["O0 keep integer-to-float32 CAST code size: "
			cast-keep-f32-code-size lf]
		failures: failures + 1
	]
]

set-cast-case cast-ir -9 1069547520 0 -5 1
size: x64-codegen/generate cast-ir 141 output 1024 0
if any [size <= 0 not execute-first? output 1069547520][
	print ["bit-preserving float32-to-integer cast failed" lf]
	failures: failures + 1
]
if size > 0 [
	fn: as codegen-function! (output + x64-codegen/IMAGE_HEADER_SIZE)
	cast-keep-integer-code-size: fn/code-size
	if cast-keep-integer-code-size <> 32 [
		print ["O0 keep float32-to-integer CAST code size: "
			cast-keep-integer-code-size lf]
		failures: failures + 1
	]
]

set-cast-case cast-ir -10 0 1073217536 -9 0
size: x64-codegen/generate cast-ir 141 output 1024 0
if any [size <= 0 not execute-floating32? output 1.5][
	print ["numeric float-to-float32 cast was rejected" lf]
	failures: failures + 1
]
if size > 0 [
	fn: as codegen-function! (output + x64-codegen/IMAGE_HEADER_SIZE)
	cast-float-width-code-size: fn/code-size
	if cast-float-width-code-size <> 44 [
		print ["O0 float width CAST code size: " cast-float-width-code-size lf]
		failures: failures + 1
	]
]

set-cast-case cast-ir -5 3 0 -10 0
size: x64-codegen/generate cast-ir 141 output 1024 0
if any [size <= 0 not execute-floating? output 3.0][
	print ["numeric integer-to-float cast failed" lf]
	failures: failures + 1
]
if size > 0 [
	fn: as codegen-function! (output + x64-codegen/IMAGE_HEADER_SIZE)
	cast-integer-float-code-size: fn/code-size
	if cast-integer-float-code-size <> 31 [
		print ["O0 integer-to-float CAST code size: " cast-integer-float-code-size lf]
		failures: failures + 1
	]
]

set-cast-case cast-ir -10 0 1073217536 -5 0
size: x64-codegen/generate cast-ir 141 output 1024 0
if any [size <= 0 not execute-first? output 1][
	print ["numeric float-to-integer cast failed" lf]
	failures: failures + 1
]

set-cast-case cast-ir -10 0 1073217536 -15 0
if (x64-codegen/generate cast-ir 141 output 1024 0) <> x64-codegen/INVALID_IR [
	print ["float-to-byte cast was accepted" lf]
	failures: failures + 1
]

set-cast-case cast-ir -13 0 0 -15 0
if (x64-codegen/generate cast-ir 141 output 1024 0) <> x64-codegen/INVALID_IR [
	print ["c-string-to-byte cast was accepted" lf]
	failures: failures + 1
]

set-cast-case cast-ir -12 0 0 -15 0
if (x64-codegen/generate cast-ir 141 output 1024 0) <> x64-codegen/INVALID_IR [
	print ["pointer-to-byte cast was accepted" lf]
	failures: failures + 1
]

set-cast-case cast-ir -15 1 0 -12 0
if (x64-codegen/generate cast-ir 141 output 1024 0) <> x64-codegen/INVALID_IR [
	print ["byte-to-pointer cast was accepted" lf]
	failures: failures + 1
]

set-cast-case cast-ir -2 1 0 -12 0
if (x64-codegen/generate cast-ir 141 output 1024 0) <= 0 [
	print ["uint8-to-pointer cast was rejected as byte!" lf]
	failures: failures + 1
]

set-cast-case cast-ir -11 1 0 -12 0
if (x64-codegen/generate cast-ir 141 output 1024 0) <> x64-codegen/INVALID_IR [
	print ["logic-to-pointer cast was accepted" lf]
	failures: failures + 1
]

set-cast-case cast-ir -4 1 0 1 0
if (x64-codegen/generate cast-ir 141 output 1024 0) <> x64-codegen/INVALID_IR [
	print ["narrow integer-to-function cast was accepted" lf]
	failures: failures + 1
]

set-cast-case cast-ir -5 1 0 1 0
if (x64-codegen/generate cast-ir 141 output 1024 0) <= 0 [
	print ["integer-to-function cast was rejected" lf]
	failures: failures + 1
]

set-cast-case cast-ir -10 0 1073217536 -9 1
if (x64-codegen/generate cast-ir 141 output 1024 0) <> x64-codegen/INVALID_IR [
	print ["bit-preserving float64-to-float32 cast was accepted" lf]
	failures: failures + 1
]

set-cast-case cast-ir -5 1 0 -10 1
if (x64-codegen/generate cast-ir 141 output 1024 0) <> x64-codegen/INVALID_IR [
	print ["bit-preserving integer-to-float64 cast was accepted" lf]
	failures: failures + 1
]

put cast-ir 36 -1
put cast-ir 40 -15
set-cast-case cast-ir 1 1 0 -12 0
if (x64-codegen/generate cast-ir 141 output 1024 0) <> x64-codegen/INVALID_IR [
	print ["byte! alias lost its cast category" lf]
	failures: failures + 1
]

put cast-ir 40 -2
if (x64-codegen/generate cast-ir 141 output 1024 0) <= 0 [
	print ["uint8! alias was classified as byte!" lf]
	failures: failures + 1
]

; CAST keeps a canonical register value for the next consumer. These chains
; compare the widened result so stale high bits cannot hide behind a narrow ABI.
put cast-flow-ir 0 1
put cast-flow-ir 4 0
put cast-flow-ir 8 0
put cast-flow-ir 12 0
put cast-flow-ir 16 1
put cast-flow-ir 20 5
put cast-flow-ir 24 0
put cast-flow-ir 28 0
put cast-flow-ir 32 0
put cast-flow-ir 36 0
put cast-flow-ir 40 2
put cast-flow-ir 44 -11
put cast-flow-ir 48 0
put cast-flow-ir 52 0
put cast-flow-ir 56 0
put cast-flow-ir 60 0
put cast-flow-ir 64 0
put cast-flow-ir 68 5
put-instruction cast-flow-ir 72 1 -5 -1 0
put-instruction cast-flow-ir 88 8 -7 0 0
put-instruction cast-flow-ir 104 1 -7 -1 -1
put-instruction cast-flow-ir 120 15 13 0 0
put-instruction cast-flow-ir 136 11 -11 0 0
cast-flow-ir/153: as byte! 63h
cast-flow-ir/154: as byte! 66h
if any [
	(x64-codegen/generate cast-flow-ir 154 output 1024 0) <= 0
	not execute-first? output 1
][
	print ["O0 signed integer CAST widening was not canonical" lf]
	failures: failures + 1
]

put cast-flow-ir 20 6
put cast-flow-ir 68 6
put-instruction cast-flow-ir 72 1 -5 257 0
put-instruction cast-flow-ir 88 8 -15 0 0
put-instruction cast-flow-ir 104 8 -7 0 0
put-instruction cast-flow-ir 120 1 -7 1 0
put-instruction cast-flow-ir 136 15 13 0 0
put-instruction cast-flow-ir 152 11 -11 0 0
cast-flow-ir/169: as byte! 63h
cast-flow-ir/170: as byte! 66h
if any [
	(x64-codegen/generate cast-flow-ir 170 output 1024 0) <= 0
	not execute-first? output 1
][
	print ["O0 byte CAST truncation was not canonical" lf]
	failures: failures + 1
]

put-instruction cast-flow-ir 72 1 -7 -1 1
put-instruction cast-flow-ir 88 8 -5 0 0
put-instruction cast-flow-ir 104 8 -7 0 0
put-instruction cast-flow-ir 120 1 -7 -1 -1
if any [
	(x64-codegen/generate cast-flow-ir 170 output 1024 0) <= 0
	not execute-first? output 1
][
	print ["O0 int64 CAST truncation retained stale high bits" lf]
	failures: failures + 1
]

; Address initializers retain their source type. Native validation accepts only
; casts whose target can hold the relocation representation unchanged.
put static-cast-ir 0 1
put static-cast-ir 4 0
put static-cast-ir 8 1
put static-cast-ir 12 0
put static-cast-ir 16 1
put static-cast-ir 20 1
put static-cast-ir 24 1
put static-cast-ir 28 0
put static-cast-ir 32 0

put static-cast-ir 36 -4
put static-cast-ir 40 0
put static-cast-ir 44 0
put static-cast-ir 48 0
put static-cast-ir 52 0

put static-cast-ir 56 0
put static-cast-ir 60 1
put static-cast-ir 64 -15
put static-cast-ir 68 0
put static-cast-ir 72 0
put static-cast-ir 76 1

put static-cast-ir 80 1
put static-cast-ir 84 1
put static-cast-ir 88 0
put static-cast-ir 92 0
put static-cast-ir 96 0
put static-cast-ir 100 0
put static-cast-ir 104 0
put static-cast-ir 108 0
put static-cast-ir 112 1

put static-cast-ir 116 2
put static-cast-ir 120 4
put static-cast-ir 124 1
put static-cast-ir 128 1
put-instruction static-cast-ir 132 11 0 0 0
static-cast-ir/149: as byte! 67h
static-cast-ir/150: as byte! 66h

if (x64-codegen/generate static-cast-ir 150 output 1024 0)
	<> x64-codegen/INVALID_IR [
	print ["static function-to-byte cast was accepted" lf]
	failures: failures + 1
]
put static-cast-ir 64 -5
if (x64-codegen/generate static-cast-ir 150 output 1024 0) <= 0 [
	print ["static function-to-integer cast was rejected" lf]
	failures: failures + 1
]

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
put tagged-ir 148 0
if (x64-codegen/generate tagged-ir 318 output 1024 0) <> x64-codegen/INVALID_IR [
	print ["TAG accepted a raw union" lf]
	failures: failures + 1
]
put tagged-ir 44 1
put tagged-ir 148 1
put tagged-ir 132 2
if (x64-codegen/generate tagged-ir 318 output 1024 0) <> x64-codegen/INVALID_IR [
	failures: failures + 1
]
put tagged-ir 132 1

; fn: func [return: [integer!]][either true [return 7][return 9]]
; A canonical logic GPR is consumed by BRANCH without a frame round-trip.
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
if size > 0 [
	fn: as codegen-function! (output + x64-codegen/IMAGE_HEADER_SIZE)
	branch-code-size: fn/code-size
	if branch-code-size <> 46 [
		print ["O0 direct BRANCH code size: " branch-code-size lf]
		failures: failures + 1
	]
	if not execute-first? output 7 [failures: failures + 1]
]
put branch-ir 80 0
size: x64-codegen/generate branch-ir 170 output 1024 0
if any [size <= 0 not execute-first? output 9][failures: failures + 1]
put branch-ir 80 1
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

; The fallthrough CAST reaches a RETURN which is also a branch target. It must
; materialize the byte in the shared stack slot before the two paths merge.
put branch-ir 20 7
put branch-ir 44 -15
put branch-ir 68 7
put-instruction branch-ir 72 1 -15 2 0
put-instruction branch-ir 88 1 -11 1 0
put-instruction branch-ir 104 17 7 0 0
put-instruction branch-ir 120 12 0 0 0
put-instruction branch-ir 136 1 -5 257 0
put-instruction branch-ir 152 8 -15 0 0
put-instruction branch-ir 168 11 -15 0 0
branch-ir/185: as byte! 66h
branch-ir/186: as byte! 6Eh
if any [
	(x64-codegen/generate branch-ir 186 output 1024 0) <= 0
	not execute-first? output 1
][
	print ["O0 CAST fallthrough was not materialized at merge" lf]
	failures: failures + 1
]
put branch-ir 96 0
if any [
	(x64-codegen/generate branch-ir 186 output 1024 0) <= 0
	not execute-first? output 2
][
	print ["O0 CAST merge lost its branch value" lf]
	failures: failures + 1
]

; A scalar CALL already returns in RAX or XMM0. A linear consumer uses that
; value directly; only paths which need a stack home materialize it.
put call-result-ir 0 1
put call-result-ir 4 0
put call-result-ir 8 0
put call-result-ir 12 0
put call-result-ir 16 2
put call-result-ir 20 8
put call-result-ir 24 0
put call-result-ir 28 0
put call-result-ir 32 0

put call-result-ir 36 0
put call-result-ir 40 1
put call-result-ir 44 -5
put call-result-ir 48 0
put call-result-ir 52 0
put call-result-ir 56 0
put call-result-ir 60 0
put call-result-ir 64 0
put call-result-ir 68 6

put call-result-ir 72 1
put call-result-ir 76 1
put call-result-ir 80 -11
put call-result-ir 84 0
put call-result-ir 88 0
put call-result-ir 92 0
put call-result-ir 96 0
put call-result-ir 100 0
put call-result-ir 104 2

put-instruction call-result-ir 108 7 2 0 -11
put-instruction call-result-ir 124 17 5 0 0
put-instruction call-result-ir 140 1 -5 7 0
put-instruction call-result-ir 156 11 -5 0 0
put-instruction call-result-ir 172 1 -5 9 0
put-instruction call-result-ir 188 11 -5 0 0
put-instruction call-result-ir 204 1 -11 1 0
put-instruction call-result-ir 220 11 -11 0 0
call-result-ir/237: as byte! 63h
call-result-ir/238: as byte! 72h

size: x64-codegen/generate call-result-ir 238 output 1024 0
if size <= 0 [failures: failures + 1]
if size > 0 [
	fn: as codegen-function! (output + x64-codegen/IMAGE_HEADER_SIZE)
	call-branch-code-size: fn/code-size
	if call-branch-code-size <> 46 [
		print ["O0 CALL to BRANCH code size: " call-branch-code-size lf]
		failures: failures + 1
	]
	if not execute-first? output 7 [failures: failures + 1]
]
put call-result-ir 212 0
size: x64-codegen/generate call-result-ir 238 output 1024 0
if any [size <= 0 not execute-first? output 9][failures: failures + 1]

put call-result-ir 20 6
put call-result-ir 44 -5
put call-result-ir 68 4
put call-result-ir 80 -5
put call-result-ir 104 2
put-instruction call-result-ir 108 7 2 0 -5
put-instruction call-result-ir 124 12 0 0 0
put-instruction call-result-ir 140 1 -5 7 0
put-instruction call-result-ir 156 11 -5 0 0
put-instruction call-result-ir 172 1 -5 9 0
put-instruction call-result-ir 188 11 -5 0 0
call-result-ir/205: as byte! 63h
call-result-ir/206: as byte! 72h

size: x64-codegen/generate call-result-ir 206 output 1024 0
if size <= 0 [failures: failures + 1]
if size > 0 [
	fn: as codegen-function! (output + x64-codegen/IMAGE_HEADER_SIZE)
	call-drop-code-size: fn/code-size
	if call-drop-code-size <> 31 [
		print ["O0 CALL to DROP code size: " call-drop-code-size lf]
		failures: failures + 1
	]
	if not execute-first? output 7 [failures: failures + 1]
]

put call-result-ir 20 4
put call-result-ir 44 -10
put call-result-ir 68 2
put call-result-ir 80 -10
put call-result-ir 104 2
put-instruction call-result-ir 108 7 2 0 -10
put-instruction call-result-ir 124 11 -10 0 0
put-instruction call-result-ir 140 1 -10 0 1073217536
put-instruction call-result-ir 156 11 -10 0 0
call-result-ir/173: as byte! 63h
call-result-ir/174: as byte! 72h

size: x64-codegen/generate call-result-ir 174 output 1024 0
if size <= 0 [failures: failures + 1]
if size > 0 [
	fn: as codegen-function! (output + x64-codegen/IMAGE_HEADER_SIZE)
	call-float-code-size: fn/code-size
	if call-float-code-size <> 26 [
		print ["O0 floating CALL to RETURN code size: " call-float-code-size lf]
		failures: failures + 1
	]
	if not execute-floating? output 1.5 [failures: failures + 1]
]

put call-result-ir 44 -5
put call-result-ir 80 -1
put-instruction call-result-ir 108 7 2 0 -1
put-instruction call-result-ir 124 11 -5 0 0
put-instruction call-result-ir 140 1 -1 -1 0
put-instruction call-result-ir 156 11 -1 0 0

size: x64-codegen/generate call-result-ir 174 output 1024 0
if size <= 0 [failures: failures + 1]
if size > 0 [
	fn: as codegen-function! (output + x64-codegen/IMAGE_HEADER_SIZE)
	call-narrow-code-size: fn/code-size
	if call-narrow-code-size <> 29 [
		print ["O0 narrow CALL normalization code size: " call-narrow-code-size lf]
		failures: failures + 1
	]
	if not execute-first? output -1 [failures: failures + 1]
]

; CAST consumes scalar CALL results in their ABI result registers. Cover both
; numeric and bit-preserving transitions in both register directions.
put call-result-ir 20 5
put call-result-ir 44 -15
put call-result-ir 68 3
put call-result-ir 80 -5
put call-result-ir 104 2
put-instruction call-result-ir 108 7 2 0 -5
put-instruction call-result-ir 124 8 -15 0 0
put-instruction call-result-ir 140 11 -15 0 0
put-instruction call-result-ir 156 1 -5 257 0
put-instruction call-result-ir 172 11 -5 0 0
call-result-ir/189: as byte! 63h
call-result-ir/190: as byte! 72h
size: x64-codegen/generate call-result-ir 190 output 1024 0
if any [size <= 0 not execute-first? output 1][
	print ["O0 integer CALL to CAST failed" lf]
	failures: failures + 1
]
if size > 0 [
	fn: as codegen-function! (output + x64-codegen/IMAGE_HEADER_SIZE)
	call-cast-integer-code-size: fn/code-size
	if call-cast-integer-code-size <> 29 [
		print ["O0 integer CALL to CAST code size: "
			call-cast-integer-code-size lf]
		failures: failures + 1
	]
]

put call-result-ir 44 -9
put call-result-ir 80 -10
put-instruction call-result-ir 108 7 2 0 -10
put-instruction call-result-ir 124 8 -9 0 0
put-instruction call-result-ir 140 11 -9 0 0
put-instruction call-result-ir 156 1 -10 0 1073217536
put-instruction call-result-ir 172 11 -10 0 0
size: x64-codegen/generate call-result-ir 190 output 1024 0
if any [size <= 0 not execute-floating32? output 1.5][
	print ["O0 floating CALL to CAST failed" lf]
	failures: failures + 1
]
if size > 0 [
	fn: as codegen-function! (output + x64-codegen/IMAGE_HEADER_SIZE)
	call-cast-float-code-size: fn/code-size
	if call-cast-float-code-size <> 30 [
		print ["O0 floating CALL to CAST code size: " call-cast-float-code-size lf]
		failures: failures + 1
	]
]

put call-result-ir 44 -5
put call-result-ir 80 -9
put-instruction call-result-ir 108 7 2 0 -9
put-instruction call-result-ir 124 8 -5 0 1
put-instruction call-result-ir 140 11 -5 0 0
put-instruction call-result-ir 156 1 -9 1069547520 0
put-instruction call-result-ir 172 11 -9 0 0
if any [
	(x64-codegen/generate call-result-ir 190 output 1024 0) <= 0
	not execute-first? output 1069547520
][
	print ["O0 float32 CALL keep CAST failed" lf]
	failures: failures + 1
]

put call-result-ir 44 -9
put call-result-ir 80 -5
put-instruction call-result-ir 108 7 2 0 -5
put-instruction call-result-ir 124 8 -9 0 1
put-instruction call-result-ir 140 11 -9 0 0
put-instruction call-result-ir 156 1 -5 1069547520 0
put-instruction call-result-ir 172 11 -5 0 0
if any [
	(x64-codegen/generate call-result-ir 190 output 1024 0) <= 0
	not execute-floating32? output 1.5
][
	print ["O0 integer CALL keep CAST failed" lf]
	failures: failures + 1
]

; A linear scalar producer is the last logical CALL argument. The fixed ABI
; consumes the signed int8 value directly while widening it to int64.
put call-argument-ir 0 1
put call-argument-ir 4 0
put call-argument-ir 8 0
put call-argument-ir 12 0
put call-argument-ir 16 2
put call-argument-ir 20 6
put call-argument-ir 24 0
put call-argument-ir 28 0
put call-argument-ir 32 0

put call-argument-ir 36 0
put call-argument-ir 40 1
put call-argument-ir 44 -7
put call-argument-ir 48 0
put call-argument-ir 52 0
put call-argument-ir 56 0
put call-argument-ir 60 0
put call-argument-ir 64 0
put call-argument-ir 68 3

put call-argument-ir 72 1
put call-argument-ir 76 1
put call-argument-ir 80 -7
put call-argument-ir 84 0
put call-argument-ir 88 0
put call-argument-ir 92 1
put call-argument-ir 96 1
put call-argument-ir 100 0
put call-argument-ir 104 3

put call-argument-ir 108 -7
put call-argument-ir 112 0
put-instruction call-argument-ir 116 1 -1 -2 -1
put-instruction call-argument-ir 132 7 2 1 -7
put-instruction call-argument-ir 148 11 -7 0 0
put-instruction call-argument-ir 164 3 1 1 0
put-instruction call-argument-ir 180 4 0 0 0
put-instruction call-argument-ir 196 11 -7 0 0
call-argument-ir/213: as byte! 61h
call-argument-ir/214: as byte! 62h

size: x64-codegen/generate call-argument-ir 214 output 1024 0
if any [size <= 0 not execute-first? output -2][
	print ["O0 fixed scalar CALL argument failed" lf]
	failures: failures + 1
]
if size > 0 [
	fn: as codegen-function! (output + x64-codegen/IMAGE_HEADER_SIZE)
	call-argument-code-size: fn/code-size
	if call-argument-code-size <> 36 [
		print ["O0 fixed argument code size: " call-argument-code-size lf]
		failures: failures + 1
	]
]

; A one-value packed CALL can write the live RAX value directly into its list.
; There is no earlier packed value that requires staging through R11.
put call-argument-ir 0 1
put call-argument-ir 4 0
put call-argument-ir 8 1
put call-argument-ir 12 0
put call-argument-ir 16 2
put call-argument-ir 20 6
put call-argument-ir 24 0
put call-argument-ir 28 0
put call-argument-ir 32 0

put call-argument-ir 36 -6
put call-argument-ir 40 -8
put call-argument-ir 44 0
put call-argument-ir 48 0
put call-argument-ir 52 0

put call-argument-ir 56 0
put call-argument-ir 60 1
put call-argument-ir 64 -5
put call-argument-ir 68 0
put call-argument-ir 72 0
put call-argument-ir 76 0
put call-argument-ir 80 0
put call-argument-ir 84 0
put call-argument-ir 88 3

put call-argument-ir 92 1
put call-argument-ir 96 1
put call-argument-ir 100 -5
put call-argument-ir 104 x64-codegen/VARIADIC
put call-argument-ir 108 0
put call-argument-ir 112 2
put call-argument-ir 116 2
put call-argument-ir 120 0
put call-argument-ir 124 3

put call-argument-ir 128 -5
put call-argument-ir 132 0
put call-argument-ir 136 1
put call-argument-ir 140 0
put-instruction call-argument-ir 144 1 -5 41 0
put-instruction call-argument-ir 160 7 2 1 -5
put-instruction call-argument-ir 176 11 -5 0 0
put-instruction call-argument-ir 192 3 1 1 0
put-instruction call-argument-ir 208 4 0 0 0
put-instruction call-argument-ir 224 11 -5 0 0
call-argument-ir/241: as byte! 61h
call-argument-ir/242: as byte! 62h

size: x64-codegen/generate call-argument-ir 242 output 1024 0
if size <= 0 [
	print ["O0 one-value packed CALL generate status: " size lf]
	failures: failures + 1
]
if size > 0 [
	fn: as codegen-function! (output + x64-codegen/IMAGE_HEADER_SIZE)
	if fn/code-size <> 52 [
		print ["O0 one-value packed code size: " fn/code-size lf]
		failures: failures + 1
	]
	unless execute-first? output 1 [
		print ["O0 one-value packed CALL execution failed" lf]
		failures: failures + 1
	]
]

; The second floating argument is a live CALL result in XMM0. Loading the
; earlier floating argument must not destroy it before the fixed CALL.
put float-argument-ir 0 1
put float-argument-ir 4 0
put float-argument-ir 8 0
put float-argument-ir 12 0
put float-argument-ir 16 3
put float-argument-ir 20 9
put float-argument-ir 24 0
put float-argument-ir 28 0
put float-argument-ir 32 0

put float-argument-ir 36 0
put float-argument-ir 40 1
put float-argument-ir 44 -10
put float-argument-ir 48 0
put float-argument-ir 52 0
put float-argument-ir 56 0
put float-argument-ir 60 0
put float-argument-ir 64 0
put float-argument-ir 68 4

put float-argument-ir 72 1
put float-argument-ir 76 1
put float-argument-ir 80 -10
put float-argument-ir 84 0
put float-argument-ir 88 0
put float-argument-ir 92 2
put float-argument-ir 96 2
put float-argument-ir 100 0
put float-argument-ir 104 3

put float-argument-ir 108 2
put float-argument-ir 112 1
put float-argument-ir 116 -10
put float-argument-ir 120 0
put float-argument-ir 124 2
put float-argument-ir 128 0
put float-argument-ir 132 2
put float-argument-ir 136 0
put float-argument-ir 140 2

put float-argument-ir 144 -10
put float-argument-ir 148 0
put float-argument-ir 152 -10
put float-argument-ir 156 0
put-instruction float-argument-ir 160 1 -10 0 3FF00000h
put-instruction float-argument-ir 176 7 3 0 -10
put-instruction float-argument-ir 192 7 2 2 -10
put-instruction float-argument-ir 208 11 -10 0 0
put-instruction float-argument-ir 224 3 1 2 0
put-instruction float-argument-ir 240 4 0 0 0
put-instruction float-argument-ir 256 11 -10 0 0
put-instruction float-argument-ir 272 1 -10 0 3FF80000h
put-instruction float-argument-ir 288 11 -10 0 0
float-argument-ir/305: as byte! 61h
float-argument-ir/306: as byte! 62h
float-argument-ir/307: as byte! 63h

size: x64-codegen/generate float-argument-ir 307 output 1024 0
if any [size <= 0 not execute-floating? output 1.5][
	print ["O0 floating CALL argument staging failed" lf]
	failures: failures + 1
]
if size > 0 [
	fn: as codegen-function! (output + x64-codegen/IMAGE_HEADER_SIZE)
	call-float-argument-code-size: fn/code-size
	if call-float-argument-code-size <> 58 [
		print ["O0 floating argument code size: " call-float-argument-code-size lf]
		failures: failures + 1
	]
]

; The fifth physical argument is a live floating CALL result in XMM0. It is
; staged in XMM4 while four earlier register arguments are marshaled, then
; written once without changing the logical argument loop index.
put float-argument-ir 0 1
put float-argument-ir 4 0
put float-argument-ir 8 0
put float-argument-ir 12 0
put float-argument-ir 16 3
put float-argument-ir 20 12
put float-argument-ir 24 0
put float-argument-ir 28 0
put float-argument-ir 32 0

put float-argument-ir 36 0
put float-argument-ir 40 1
put float-argument-ir 44 -10
put float-argument-ir 48 0
put float-argument-ir 52 0
put float-argument-ir 56 0
put float-argument-ir 60 0
put float-argument-ir 64 0
put float-argument-ir 68 7

put float-argument-ir 72 1
put float-argument-ir 76 1
put float-argument-ir 80 -10
put float-argument-ir 84 0
put float-argument-ir 88 0
put float-argument-ir 92 5
put float-argument-ir 96 5
put float-argument-ir 100 0
put float-argument-ir 104 3

put float-argument-ir 108 2
put float-argument-ir 112 1
put float-argument-ir 116 -10
put float-argument-ir 120 0
put float-argument-ir 124 5
put float-argument-ir 128 0
put float-argument-ir 132 5
put float-argument-ir 136 0
put float-argument-ir 140 2

put float-argument-ir 144 -5
put float-argument-ir 148 0
put float-argument-ir 152 -5
put float-argument-ir 156 0
put float-argument-ir 160 -5
put float-argument-ir 164 0
put float-argument-ir 168 -5
put float-argument-ir 172 0
put float-argument-ir 176 -10
put float-argument-ir 180 0

put-instruction float-argument-ir 184 1 -5 0 0
put-instruction float-argument-ir 200 1 -5 0 0
put-instruction float-argument-ir 216 1 -5 0 0
put-instruction float-argument-ir 232 1 -5 0 0
put-instruction float-argument-ir 248 7 3 0 -10
put-instruction float-argument-ir 264 7 2 5 -10
put-instruction float-argument-ir 280 11 -10 0 0
put-instruction float-argument-ir 296 3 1 5 0
put-instruction float-argument-ir 312 4 0 0 0
put-instruction float-argument-ir 328 11 -10 0 0
put-instruction float-argument-ir 344 1 -10 0 1073217536
put-instruction float-argument-ir 360 11 -10 0 0
float-argument-ir/377: as byte! 61h
float-argument-ir/378: as byte! 62h
float-argument-ir/379: as byte! 63h

size: x64-codegen/generate float-argument-ir 379 output 1024 0
if any [size <= 0 not execute-floating? output 1.5][
	print ["O0 floating stack CALL argument failed" lf]
	failures: failures + 1
]
if size > 0 [
	fn: as codegen-function! (output + x64-codegen/IMAGE_HEADER_SIZE)
	if fn/code-size <> 87 [
		print ["O0 floating stack argument code size: " fn/code-size lf]
		failures: failures + 1
	]
]

; A boolean diamond materializes the truth value already on the postfix stack.
; O0 keeps the operation-level cost at 14 bytes and normalizes every nonzero
; condition to the canonical logic value 1 without emitting control flow.
put boolean-ir 0 1
put boolean-ir 4 0
put boolean-ir 8 0
put boolean-ir 12 0
put boolean-ir 16 1
put boolean-ir 20 2
put boolean-ir 24 0
put boolean-ir 28 0
put boolean-ir 32 0
put boolean-ir 36 0
put boolean-ir 40 2
put boolean-ir 44 -11
put boolean-ir 48 0
put boolean-ir 52 0
put boolean-ir 56 0
put boolean-ir 60 0
put boolean-ir 64 0
put boolean-ir 68 2
put-instruction boolean-ir 72 1 -11 0 0
put-instruction boolean-ir 88 11 -11 0 0
boolean-ir/105: as byte! 62h
boolean-ir/106: as byte! 6Eh

size: x64-codegen/generate boolean-ir 106 output 1024 0
if any [size <= 0 not execute-first? output 0][
	print ["boolean identity fixture failed" lf]
	failures: failures + 1
]
if size > 0 [
	fn: as codegen-function! (output + x64-codegen/IMAGE_HEADER_SIZE)
	identity-code-size: fn/code-size
]

put boolean-ir 20 6
put boolean-ir 68 6
put-instruction boolean-ir 72 1 -11 0 0
put-instruction boolean-ir 88 17 5 0 0
put-instruction boolean-ir 104 1 -11 1 0
put-instruction boolean-ir 120 16 6 0 0
put-instruction boolean-ir 136 1 -11 0 0
put-instruction boolean-ir 152 11 -11 0 0
boolean-ir/169: as byte! 62h
boolean-ir/170: as byte! 6Eh

size: x64-codegen/generate boolean-ir 170 output 1024 0
if any [size <= 0 not execute-first? output 0][
	print ["boolean diamond false path failed" lf]
	failures: failures + 1
]
if size > 0 [
	fn: as codegen-function! (output + x64-codegen/IMAGE_HEADER_SIZE)
	folded-code-size: fn/code-size
	if folded-code-size <> (identity-code-size + 14)[
		print ["boolean diamond code size changed: " identity-code-size
			" / " folded-code-size lf]
		failures: failures + 1
	]
]
put boolean-ir 80 7
size: x64-codegen/generate boolean-ir 170 output 1024 0
if any [size <= 0 not execute-first? output 1][
	print ["boolean diamond did not normalize a nonzero condition" lf]
	failures: failures + 1
]

put boolean-ir 96 1
put boolean-ir 112 0
put boolean-ir 144 1
size: x64-codegen/generate boolean-ir 170 output 1024 0
if any [size <= 0 not execute-first? output 1][
	print ["reverse boolean diamond true path failed" lf]
	failures: failures + 1
]
if size > 0 [
	fn: as codegen-function! (output + x64-codegen/IMAGE_HEADER_SIZE)
	if fn/code-size <> folded-code-size [
		print ["reverse boolean diamond was not folded" lf]
		failures: failures + 1
	]
]
put boolean-ir 80 0
size: x64-codegen/generate boolean-ir 170 output 1024 0
if any [size <= 0 not execute-first? output 0][
	print ["reverse boolean diamond false path failed" lf]
	failures: failures + 1
]

; An incoming edge to any interior instruction makes the same local shape
; non-collapsible. This preserves raw RSIR control-flow targets without a CFG.
put boolean-ir 20 8
put boolean-ir 68 8
put-instruction boolean-ir 72 1 -11 0 0
put-instruction boolean-ir 88 17 7 1 0
put-instruction boolean-ir 104 1 -11 7 0
put-instruction boolean-ir 120 17 7 0 0
put-instruction boolean-ir 136 1 -11 1 0
put-instruction boolean-ir 152 16 8 0 0
put-instruction boolean-ir 168 1 -11 0 0
put-instruction boolean-ir 184 11 -11 0 0
boolean-ir/201: as byte! 62h
boolean-ir/202: as byte! 6Eh

size: x64-codegen/generate boolean-ir 202 output 1024 0
if any [size <= 0 not execute-first? output 1][
	print ["shared boolean diamond fixture failed" lf]
	failures: failures + 1
]
if size > 0 [
	fn: as codegen-function! (output + x64-codegen/IMAGE_HEADER_SIZE)
	if fn/code-size <= folded-code-size [
		print ["shared boolean diamond was folded across an incoming edge" lf]
		failures: failures + 1
	]
]
put boolean-ir 80 1
size: x64-codegen/generate boolean-ir 202 output 1024 0
if any [size <= 0 not execute-first? output 0][
	print ["shared boolean diamond external entry failed" lf]
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

; Direct-float provenance is lexical, not a value property that survives a
; control-flow merge. Even two literal arms must not enable f64 -> f32 CALL.
put literal-merge-ir 0 1
put literal-merge-ir 4 0
put literal-merge-ir 8 0
put literal-merge-ir 12 0
put literal-merge-ir 16 2
put literal-merge-ir 20 8
put literal-merge-ir 24 0
put literal-merge-ir 28 0
put literal-merge-ir 32 0

put literal-merge-ir 36 0
put literal-merge-ir 40 1
put literal-merge-ir 44 0
put literal-merge-ir 48 0
put literal-merge-ir 52 0
put literal-merge-ir 56 0
put literal-merge-ir 60 0
put literal-merge-ir 64 0
put literal-merge-ir 68 7

put literal-merge-ir 72 1
put literal-merge-ir 76 1
put literal-merge-ir 80 0
put literal-merge-ir 84 0
put literal-merge-ir 88 0
put literal-merge-ir 92 1
put literal-merge-ir 96 1
put literal-merge-ir 100 0
put literal-merge-ir 104 1

put literal-merge-ir 108 -9
put literal-merge-ir 112 0

put-instruction literal-merge-ir 116 1 -11 1 0
put-instruction literal-merge-ir 132 17 5 0 0
put-instruction literal-merge-ir 148 1 -10 0 1073217536
put-instruction literal-merge-ir 164 16 6 0 0
put-instruction literal-merge-ir 180 1 -10 0 1074003968
put-instruction literal-merge-ir 196 7 2 1 0
put-instruction literal-merge-ir 212 11 0 0 0
put-instruction literal-merge-ir 228 11 0 0 0
literal-merge-ir/245: as byte! 61h
literal-merge-ir/246: as byte! 62h

if (x64-codegen/generate literal-merge-ir 246 output 1024 0)
	<> x64-codegen/INVALID_IR [
	print ["merged float literals retained direct-literal provenance" lf]
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

put selection-ir 88 -11
if (x64-codegen/generate selection-ir 198 output 1024 0)
	<> x64-codegen/INVALID_IR [
	print ["SWITCH accepted a logic selector" lf]
	failures: failures + 1
]
put selection-ir 88 -5

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
put system-ir 56 3
put system-ir 64 1
put system-ir 88 5
put-instruction system-ir 92 1 1 42 0
put-instruction system-ir 108 10 15 0 3
put-instruction system-ir 124 12 0 0 0
put-instruction system-ir 140 10 14 0 3
put-instruction system-ir 156 11 1 0 0
system-ir/173: as byte! 72h
system-ir/174: as byte! 63h
system-ir/175: as byte! 78h
system-ir/176: as byte! 66h
system-ir/177: as byte! 6Eh

size: x64-codegen/generate system-ir 177 output 1024 0
if any [size <= 0 not execute-first? output 42][failures: failures + 1]
system-ir/175: as byte! 7Ah
if (x64-codegen/generate system-ir 177 output 1024 0) <> x64-codegen/UNSUPPORTED [
	failures: failures + 1
]
system-ir/175: as byte! 78h
put system-ir 96 -5
if (x64-codegen/generate system-ir 177 output 1024 0) <> x64-codegen/INVALID_IR [
	failures: failures + 1
]
put system-ir 96 1

; ADD sets OF while the division family has no usable OF result.
put system-ir 64 -11
put-instruction system-ir 92 1 -5 2147483647 0
put-instruction system-ir 108 1 -5 1 0
put-instruction system-ir 124 15 1 0 0
put-instruction system-ir 140 10 16 0 -11
put-instruction system-ir 156 11 -11 0 0
size: x64-codegen/generate system-ir 177 output 1024 0
if any [size <= 0 not execute-first? output 1][failures: failures + 1]

put-instruction system-ir 108 1 -5 -1 -1
put-instruction system-ir 124 15 4 0 0
size: x64-codegen/generate system-ir 177 output 1024 0
if any [size <= 0 not execute-first? output 0][failures: failures + 1]
put system-ir 152 0
if (x64-codegen/generate system-ir 177 output 1024 0) <> x64-codegen/INVALID_IR [
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
put atomic-ir 40 -5

; Atomic STORE consumes an ordinary pointer and value. Both operand types are
; native-owned; the independent result literal follows the void operation.
put atomic-ir 20 6
put atomic-ir 88 6
put-instruction atomic-ir 100 3 1 1 0
put-instruction atomic-ir 116 20 1 0 0
put-instruction atomic-ir 132 1 -5 5 0
put-instruction atomic-ir 148 10 19 0 0
put-instruction atomic-ir 164 1 -5 7 0
put-instruction atomic-ir 180 11 -5 0 0
atomic-ir/197: as byte! 66h
atomic-ir/198: as byte! 6Eh
size: x64-codegen/generate atomic-ir 198 output 1024 0
if any [size <= 0 not execute-first? output 7][
	print ["atomic STORE fixture failed" lf]
	failures: failures + 1
]
put atomic-ir 136 -11
if (x64-codegen/generate atomic-ir 198 output 1024 0) <> x64-codegen/INVALID_IR [
	print ["atomic STORE accepted a logic value" lf]
	failures: failures + 1
]
put atomic-ir 136 -5
put atomic-ir 40 -15
if (x64-codegen/generate atomic-ir 198 output 1024 0) <> x64-codegen/INVALID_IR [
	print ["atomic STORE accepted a byte pointer" lf]
	failures: failures + 1
]
put atomic-ir 40 -5

; Atomic LOAD replaces its pointer with one integer value.
put-instruction atomic-ir 100 3 1 1 0
put-instruction atomic-ir 116 20 1 0 0
put-instruction atomic-ir 132 10 18 0 -5
put-instruction atomic-ir 148 12 0 0 0
put-instruction atomic-ir 164 1 -5 7 0
put-instruction atomic-ir 180 11 -5 0 0
size: x64-codegen/generate atomic-ir 198 output 1024 0
if any [size <= 0 not execute-first? output 7][
	print ["atomic LOAD fixture failed" lf]
	failures: failures + 1
]
put atomic-ir 144 -11
if (x64-codegen/generate atomic-ir 198 output 1024 0) <> x64-codegen/INVALID_IR [
	print ["atomic LOAD accepted the wrong result type" lf]
	failures: failures + 1
]
put atomic-ir 144 -5
put atomic-ir 40 -15
if (x64-codegen/generate atomic-ir 198 output 1024 0) <> x64-codegen/INVALID_IR [
	print ["atomic LOAD accepted a byte pointer" lf]
	failures: failures + 1
]
put atomic-ir 40 -5

; Atomic CAS consumes pointer, check, and replacement values and returns logic.
put atomic-ir 20 9
put atomic-ir 88 9
put-instruction atomic-ir 100 1 -5 7 0
put-instruction atomic-ir 116 3 1 1 0
put-instruction atomic-ir 132 20 1 0 0
put-instruction atomic-ir 148 1 -5 1 0
put-instruction atomic-ir 164 1 -5 2 0
put-instruction atomic-ir 180 10 20 0 -11
put-instruction atomic-ir 196 12 0 0 0
put-instruction atomic-ir 212 1 -5 7 0
put-instruction atomic-ir 228 11 -5 0 0
size: x64-codegen/generate atomic-ir 246 output 1024 0
if any [size <= 0 not execute-first? output 7][
	print ["atomic CAS fixture failed" lf]
	failures: failures + 1
]
put atomic-ir 152 -11
if (x64-codegen/generate atomic-ir 246 output 1024 0) <> x64-codegen/INVALID_IR [
	print ["atomic CAS accepted a logic check value" lf]
	failures: failures + 1
]
put atomic-ir 152 -5
put atomic-ir 168 -11
if (x64-codegen/generate atomic-ir 246 output 1024 0) <> x64-codegen/INVALID_IR [
	print ["atomic CAS accepted a logic replacement value" lf]
	failures: failures + 1
]
put atomic-ir 168 -5
put atomic-ir 192 -5
if (x64-codegen/generate atomic-ir 246 output 1024 0) <> x64-codegen/INVALID_IR [
	print ["atomic CAS accepted the wrong result type" lf]
	failures: failures + 1
]
put atomic-ir 192 -11
put atomic-ir 40 -15
if (x64-codegen/generate atomic-ir 246 output 1024 0) <> x64-codegen/INVALID_IR [
	print ["atomic CAS accepted a byte pointer" lf]
	failures: failures + 1
]
put atomic-ir 40 -5

; Stack allocation and release consume slot counts through the same native
; postfix path. ALLOCATE's pointer result is explicit instruction metadata.
put-instruction atomic-ir 100 1 -5 7 0
put-instruction atomic-ir 116 1 -5 1 0
put-instruction atomic-ir 132 10 8 0 1
put-instruction atomic-ir 148 12 0 0 0
put-instruction atomic-ir 164 1 -5 1 0
put-instruction atomic-ir 180 10 10 0 0
put-instruction atomic-ir 196 1 -5 0 0
put-instruction atomic-ir 212 12 0 0 0
put-instruction atomic-ir 228 11 -5 0 0
size: x64-codegen/generate atomic-ir 246 output 1024 0
if any [size <= 0 not execute-first? output 7][
	print ["native stack allocation fixture failed" lf]
	failures: failures + 1
]
put atomic-ir 120 -11
if (x64-codegen/generate atomic-ir 246 output 1024 0) <> x64-codegen/INVALID_IR [
	print ["stack ALLOCATE accepted a logic slot count" lf]
	failures: failures + 1
]
put atomic-ir 120 -5
put atomic-ir 144 -5
if (x64-codegen/generate atomic-ir 246 output 1024 0) <> x64-codegen/INVALID_IR [
	print ["stack ALLOCATE accepted a scalar result type" lf]
	failures: failures + 1
]
put atomic-ir 144 1
put atomic-ir 168 -11
if (x64-codegen/generate atomic-ir 246 output 1024 0) <> x64-codegen/INVALID_IR [
	print ["stack FREE accepted a logic slot count" lf]
	failures: failures + 1
]
put atomic-ir 168 -5

; A lexical CATCH owns one fixed frame record. THROW resumes at END_CATCH,
; which restores the previous threshold, resume address, and stack pointer.
put exception-ir 0 1
put exception-ir 4 0
put exception-ir 8 0
put exception-ir 12 0
put exception-ir 16 1
put exception-ir 20 9
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
put exception-ir 64 1
put exception-ir 68 9

put exception-ir 72 -5
put exception-ir 76 0
put-instruction exception-ir 80 1 -5 1 0
put-instruction exception-ir 96 24 6 1 0
put-instruction exception-ir 112 1 -5 1 0
put-instruction exception-ir 128 3 1 1 0
put-instruction exception-ir 144 26 0 0 0
put-instruction exception-ir 160 25 2 1 0
put-instruction exception-ir 176 3 1 1 0
put-instruction exception-ir 192 4 0 0 0
put-instruction exception-ir 208 11 -5 0 0
exception-ir/225: as byte! 66h
exception-ir/226: as byte! 6Eh

size: x64-codegen/generate exception-ir 226 output 1024 0
if any [size <= 0 not execute-selection? output 1][
	print ["direct THROW fixture failed" lf]
	failures: failures + 1
]
put exception-ir 100 7
if (x64-codegen/generate exception-ir 226 output 1024 0) <> x64-codegen/INVALID_IR [
	print ["CATCH accepted a mismatched END_CATCH target" lf]
	failures: failures + 1
]
put exception-ir 100 6
put exception-ir 104 2
if (x64-codegen/generate exception-ir 226 output 1024 0) <> x64-codegen/INVALID_IR [
	print ["CATCH accepted a mismatched nesting level" lf]
	failures: failures + 1
]
put exception-ir 104 1
put exception-ir 84 -11
if (x64-codegen/generate exception-ir 226 output 1024 0) <> x64-codegen/INVALID_IR [
	print ["CATCH accepted a logic filter" lf]
	failures: failures + 1
]
put exception-ir 84 -5
put exception-ir 116 -11
if (x64-codegen/generate exception-ir 226 output 1024 0) <> x64-codegen/INVALID_IR [
	print ["THROW accepted a logic ID" lf]
	failures: failures + 1
]
put exception-ir 116 -5

; THROW owns both the original ID value and the destination place.
put exception-ir 72 -11
put exception-ir 44 -11
put exception-ir 212 -11
if (x64-codegen/generate exception-ir 226 output 1024 0) <> x64-codegen/INVALID_IR [
	print ["THROW accepted a non-integer destination" lf]
	failures: failures + 1
]
put exception-ir 72 -5
put exception-ir 44 -5
put exception-ir 212 -5
put-instruction exception-ir 128 1 -5 1 0
if (x64-codegen/generate exception-ir 226 output 1024 0) <> x64-codegen/INVALID_IR [
	print ["THROW accepted a value instead of a destination place" lf]
	failures: failures + 1
]
put-instruction exception-ir 128 3 1 1 0

; JUMP carries only the number of lexical catch records it exits.
put exception-ir 120 73
put-instruction exception-ir 128 16 9 0 1
put-instruction exception-ir 144 19 1 0 0
size: x64-codegen/generate exception-ir 226 output 1024 0
if any [size <= 0 not execute-selection? output 73][
	print ["catch-unwinding JUMP fixture failed" lf]
	failures: failures + 1
]
put exception-ir 140 0
if (x64-codegen/generate exception-ir 226 output 1024 0) <> x64-codegen/INVALID_IR [
	print ["JUMP crossed a catch boundary without unwinding it" lf]
	failures: failures + 1
]
put exception-ir 120 1
put-instruction exception-ir 128 3 1 1 0
put-instruction exception-ir 144 26 0 0 0

put exception-ir 48 (x64-codegen/CATCH_FLAG + x64-codegen/CDECL)
if (x64-codegen/generate exception-ir 226 output 1024 0) <> x64-codegen/INVALID_IR [
	print ["CATCH function accepted a calling convention" lf]
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

; A declared result from a no-return callee has no live register value. The
; disconnected instruction after CALL must therefore start without a location.
put no-return-ir 20 3
put no-return-ir 68 2
put no-return-ir 80 -11
put-instruction no-return-ir 108 7 2 0 -11
put-instruction no-return-ir 124 19 1 0 0
put-instruction no-return-ir 140 19 1 0 0
no-return-ir/157: as byte! 66h
no-return-ir/158: as byte! 31h
no-return-ir/159: as byte! 66h
no-return-ir/160: as byte! 32h
if (x64-codegen/generate no-return-ir 160 output 1024 0) <= 0 [
	print ["typed no-return CALL retained a live result" lf]
	failures: failures + 1
]
put no-return-ir 20 2
put no-return-ir 68 1
put no-return-ir 80 0
put-instruction no-return-ir 108 7 2 0 0
put-instruction no-return-ir 124 19 1 0 0
no-return-ir/141: as byte! 66h
no-return-ir/142: as byte! 31h
no-return-ir/143: as byte! 66h
no-return-ir/144: as byte! 32h

put no-return-ir 48 x64-codegen/CATCH_FLAG
if (x64-codegen/generate no-return-ir 144 output 1024 0) <> x64-codegen/INVALID_IR [
	print ["catch caller lost the continuation after a no-return call" lf]
	failures: failures + 1
]
put no-return-ir 48 0
put no-return-ir 84 0
if (x64-codegen/generate no-return-ir 144 output 1024 0) <> x64-codegen/INVALID_IR [
	failures: failures + 1
]

free output
free void-ir
free local-ir
free pointer-ir
free index-ir
free arithmetic-ir
free expression-ir
free aggregate-ir
free abi-ir
free small-return-ir
free widening-ir
free sink-ir
free signature-ir
free indirect-ir
free variadic-ir
free null-function-ir
free cast-ir
free cast-flow-ir
free static-cast-ir
free tagged-ir
free array-ir
free array-compare-ir
free branch-ir
free call-result-ir
free call-argument-ir
free float-argument-ir
free boolean-ir
free merge-ir
free literal-merge-ir
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
x64-codegen/free-signature-pairs sink-pairs
either failures = 0 [
	print ["PASS: typed postfix Windows x64 codegen" lf]
][
	print ["FAIL: typed postfix x64 codegen failures=" failures lf]
]
quit failures
