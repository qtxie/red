Red [
	Title: "Machine IR construction and verifier smoke test"
]

#include %../../../../compiler/int-to-bin.red
emitter: context [
	symbols: make hash! 8
	bits-buf: make binary! 32
	ensure-bits-buf: does [unless binary? :bits-buf [bits-buf: make binary! 32]]
	store-ptr-bitmap: func [list [block!] /local offset value][
		ensure-bits-buf
		offset: to integer! ((length? bits-buf) / 4)
		foreach value list [
			if integer? value [append bits-buf int-to-bin/to-bin32 value]
		]
		offset
	]
]
#include %../../../../system/machine-ir.red

fail: func [message [string!]][
	print ["machine-ir-smoke-failed:" message]
	quit/return 1
]

dump-path: clean-path %../../../../build/machine-ir-smoke.ir
unless rs-o2-ir/start-session 2 'X86-64 dump-path 0 no [fail "session did not start"]

i32: rs-o2-ir/make-type 'i32 4 'gpr yes 0 'none
f32: rs-o2-ir/make-type 'f32 4 'xmm yes 0 'none
f64: rs-o2-ir/make-type 'f64 8 'xmm yes 0 'none
i64: rs-o2-ir/make-type 'i64 8 'gpr yes 0 'none
ptr-type: rs-o2-ir/make-type 'ptr 8 'gpr no 4 'pointer
logic-type: rs-o2-ir/make-type 'logic 4 'gpr no 0 'none
extended-xmm-bytes: make binary! 32
rs-o2-x64/emit-xmm-move extended-xmm-bytes f64 'xmm8 'xmm9
rs-o2-x64/emit-xmm-frame-load extended-xmm-bytes f64 'xmm10 -8
rs-o2-x64/emit-xmm-binary extended-xmm-bytes f64 rs-o2-ir/add-op 'xmm8 'xmm8 'xmm9
unless extended-xmm-bytes = #{F2450F10C1F2440F1055F8F2450F58C1} [
	fail rejoin ["extended XMM REX bytes are wrong: " mold extended-xmm-bytes]
]
unless rs-o2-ir/begin-function 'smoke 'win64 i32 %machine-ir-smoke.red [
	fail "function did not start"
]

rs-o2-ir/add-stack-object 'value 'local i32 4 4 'none
rs-o2-ir/set-source %machine-ir-smoke.red 20
one: rs-o2-ir/emit-constant 1 i32
two: rs-o2-ir/emit-constant 2 i32
sum: rs-o2-ir/emit-binary '+ one two i32 'pure
rs-o2-ir/emit-store-local 'value sum i32
loaded: rs-o2-ir/emit-load-local 'value i32

direct: reduce [#{90} copy []]
rs-o2-ir/set-direct-body-range 0 1
selected: rs-o2-ir/finish-function direct

unless selected/1 = #{B803000000C3} [fail "selected bytes are wrong"]
unless (pick rs-o2-ir/stats rs-o2-ir/stats-functions) = 1 [fail "function count"]
unless (pick rs-o2-ir/stats rs-o2-ir/stats-verified) = 1 [fail "verification count"]
unless (pick rs-o2-ir/stats rs-o2-ir/stats-eligible) = 1 [fail "eligibility count"]
unless (pick rs-o2-ir/stats rs-o2-ir/stats-selected) = 1 [fail "selection count"]
unless (pick rs-o2-ir/stats rs-o2-ir/stats-fallback) = 0 [fail "unexpected fallback"]
unless loaded = 4 [fail "unexpected vreg numbering"]

unless rs-o2-ir/begin-function 'win64-args 'win64 i32 %machine-ir-smoke.red [
	fail "Win64 argument function did not start"
]
rs-o2-ir/add-stack-object 'a 'argument i32 4 4 'none
rs-o2-ir/add-stack-object 'b 'argument i32 4 4 'none
win-a: rs-o2-ir/emit-load-local 'a i32
win-b: rs-o2-ir/emit-load-local 'b i32
win-sum: rs-o2-ir/emit-binary '+ win-a win-b i32 'pure
rs-o2-ir/set-direct-body-range 0 1
win-selected: rs-o2-ir/finish-function reduce [#{90} copy []]
unless win-selected/1 = #{8D0411C3} [fail "Win64 argument bytes are wrong"]

unless rs-o2-ir/begin-function 'sysv-args 'sysv i32 %machine-ir-smoke.red [
	fail "SysV argument function did not start"
]
rs-o2-ir/add-stack-object 'a 'argument i32 4 4 'none
rs-o2-ir/add-stack-object 'b 'argument i32 4 4 'none
sysv-a: rs-o2-ir/emit-load-local 'a i32
sysv-b: rs-o2-ir/emit-load-local 'b i32
sysv-sum: rs-o2-ir/emit-binary '+ sysv-a sysv-b i32 'pure
rs-o2-ir/set-direct-body-range 0 1
sysv-selected: rs-o2-ir/finish-function reduce [#{90} copy []]
unless sysv-selected/1 = #{8D0437C3} [fail "SysV argument bytes are wrong"]

unless rs-o2-ir/begin-function 'win64-pointer-identity 'win64 ptr-type %machine-ir-smoke.red [
	fail "Win64 pointer identity function did not start"
]
rs-o2-ir/add-stack-object 'value 'argument ptr-type 8 8 'none
win-pointer-value: rs-o2-ir/emit-load-local 'value ptr-type
rs-o2-ir/set-direct-body-range 0 1
win-pointer-selected: rs-o2-ir/finish-function reduce [#{90} copy []]
unless win-pointer-selected/1 = #{4889C8C3} [
	fail rejoin ["Win64 pointer identity bytes are wrong: " mold win-pointer-selected/1]
]

unless rs-o2-ir/begin-function 'sysv-i64-identity 'sysv i64 %machine-ir-smoke.red [
	fail "SysV i64 identity function did not start"
]
rs-o2-ir/add-stack-object 'value 'argument i64 8 8 'none
sysv-i64-value: rs-o2-ir/emit-load-local 'value i64
rs-o2-ir/set-direct-body-range 0 1
sysv-i64-selected: rs-o2-ir/finish-function reduce [#{90} copy []]
unless sysv-i64-selected/1 = #{4889F8C3} [
	fail rejoin ["SysV i64 identity bytes are wrong: " mold sysv-i64-selected/1]
]

unless rs-o2-ir/begin-function 'win64-pointer-call 'win64 ptr-type %machine-ir-smoke.red [
	fail "Win64 pointer call function did not start"
]
rs-o2-ir/add-stack-object 'value 'argument ptr-type 8 8 'pointer
rs-o2-ir/set-stack-offset 'value -8
win-pointer-call-value: rs-o2-ir/emit-load-local 'value ptr-type
win-pointer-call-result: rs-o2-ir/emit-call 'pointer-callee reduce [win-pointer-call-value] ptr-type
rs-o2-ir/set-direct-body-range 0 5
pointer-callee-relocs: reduce [601]
put emitter/symbols 'pointer-callee reduce ['native none pointer-callee-relocs]
win-pointer-call-selected: rs-o2-ir/finish-function reduce [
	#{E800000000} reduce [pointer-callee-relocs] 600
]
unless win-pointer-call-selected/1 = #{488B4DF8E800000000} [
	fail rejoin ["Win64 pointer call bytes are wrong: " mold win-pointer-call-selected/1]
]
unless pointer-callee-relocs/1 = 605 [fail "pointer call relocation was not moved"]

unless rs-o2-ir/begin-function 'win64-logic-result 'win64 logic-type %machine-ir-smoke.red [
	fail "Win64 logic result function did not start"
]
rs-o2-ir/add-stack-object 'a 'argument i32 4 4 'none
rs-o2-ir/add-stack-object 'b 'argument i32 4 4 'none
logic-a: rs-o2-ir/emit-load-local 'a i32
logic-b: rs-o2-ir/emit-load-local 'b i32
logic-result: rs-o2-ir/emit-binary rs-o2-ir/less-op logic-a logic-b logic-type 'pure
rs-o2-ir/set-direct-body-range 0 1
logic-selected: rs-o2-ir/finish-function reduce [#{90} copy []]
unless logic-selected/1 = #{39D10F9CC00FB6C0C3} [fail "Win64 logic result bytes are wrong"]
sysv-logic-bytes: make binary! 8
rs-o2-x64/emit-materialized-condition sysv-logic-bytes rs-o2-ir/less-op 'edi
unless sysv-logic-bytes = #{400F9CC7400FB6FF} [fail "SysV byte-register logic bytes are wrong"]

unless rs-o2-ir/begin-function 'win64-zero-left 'win64 logic-type %machine-ir-smoke.red [
	fail "Win64 zero-left function did not start"
]
rs-o2-ir/add-stack-object 'value 'argument i32 4 4 'none
zero-left-zero: rs-o2-ir/emit-constant 0 i32
zero-left-value: rs-o2-ir/emit-load-local 'value i32
zero-left-result: rs-o2-ir/emit-binary rs-o2-ir/equal-op zero-left-zero zero-left-value logic-type 'pure
rs-o2-ir/set-direct-body-range 0 1
zero-left-selected: rs-o2-ir/finish-function reduce [#{90} copy []]
unless zero-left-selected/1 = #{85C90F94C00FB6C0C3} [
	fail rejoin ["Win64 zero-left bytes are wrong: " mold zero-left-selected/1]
]

unless rs-o2-ir/begin-function 'win64-zero-left-memory 'win64 i32 %machine-ir-smoke.red [
	fail "Win64 zero-left memory function did not start"
]
foreach [name offset] [a -8 b -16 c -24 d -32 value -40] [
	rs-o2-ir/add-stack-object name 'argument i32 4 4 'none
	rs-o2-ir/set-stack-offset name offset
]
rs-o2-ir/add-stack-object 'result 'local i32 4 4 'none
rs-o2-ir/set-stack-offset 'result -48
zero-memory-a: rs-o2-ir/emit-load-local 'a i32
zero-memory-b: rs-o2-ir/emit-load-local 'b i32
zero-memory-c: rs-o2-ir/emit-load-local 'c i32
zero-memory-d: rs-o2-ir/emit-load-local 'd i32
zero-memory-sum: rs-o2-ir/emit-binary rs-o2-ir/add-op zero-memory-a zero-memory-b i32 'pure
zero-memory-sum: rs-o2-ir/emit-binary rs-o2-ir/add-op zero-memory-sum zero-memory-c i32 'pure
zero-memory-sum: rs-o2-ir/emit-binary rs-o2-ir/add-op zero-memory-sum zero-memory-d i32 'pure
rs-o2-ir/emit-store-local 'result zero-memory-sum i32
zero-memory-if: rs-o2-ir/begin-if
zero-memory-zero: rs-o2-ir/emit-constant 0 i32
zero-memory-value: rs-o2-ir/emit-load-local 'value i32
zero-memory-test: rs-o2-ir/emit-binary rs-o2-ir/equal-op zero-memory-zero zero-memory-value logic-type 'pure
rs-o2-ir/if-condition zero-memory-if
rs-o2-ir/end-if zero-memory-if
zero-memory-result: rs-o2-ir/emit-load-local 'result i32
rs-o2-ir/set-last-result zero-memory-result i32
rs-o2-ir/set-direct-body-range 0 1
zero-memory-selected: rs-o2-ir/finish-function reduce [#{90} copy []]
unless find zero-memory-selected/1 #{837DD800} [
	fail rejoin ["Win64 zero-left memory bytes are wrong: " mold zero-memory-selected/1]
]

unless rs-o2-ir/begin-function 'win64-f64-add 'win64 f64 %machine-ir-smoke.red [
	fail "Win64 f64 function did not start"
]
rs-o2-ir/add-stack-object 'a 'argument f64 8 8 'none
rs-o2-ir/add-stack-object 'b 'argument f64 8 8 'none
win-f64-a: rs-o2-ir/emit-load-local 'a f64
win-f64-b: rs-o2-ir/emit-load-local 'b f64
win-f64-sum: rs-o2-ir/emit-binary rs-o2-ir/add-op win-f64-a win-f64-b f64 'pure
win-f64-b-again: rs-o2-ir/emit-load-local 'b f64
win-f64-result: rs-o2-ir/emit-binary rs-o2-ir/multiply-op win-f64-sum win-f64-b-again f64 'pure
rs-o2-ir/set-direct-body-range 0 1
win-f64-selected: rs-o2-ir/finish-function reduce [#{90} copy []]
unless win-f64-selected/1 = #{F20F58C1F20F59C1C3} [fail "Win64 f64 argument reload bytes are wrong"]

unless rs-o2-ir/begin-function 'sysv-f32-multiply 'sysv f32 %machine-ir-smoke.red [
	fail "SysV f32 function did not start"
]
rs-o2-ir/add-stack-object 'a 'argument f32 4 4 'none
rs-o2-ir/add-stack-object 'b 'argument f32 4 4 'none
sysv-f32-a: rs-o2-ir/emit-load-local 'a f32
sysv-f32-b: rs-o2-ir/emit-load-local 'b f32
sysv-f32-product: rs-o2-ir/emit-binary rs-o2-ir/multiply-op sysv-f32-a sysv-f32-b f32 'pure
rs-o2-ir/set-direct-body-range 0 1
sysv-f32-selected: rs-o2-ir/finish-function reduce [#{90} copy []]
unless sysv-f32-selected/1 = #{F30F59C1C3} [fail "SysV f32 argument bytes are wrong"]

unless rs-o2-ir/begin-function 'while-cfg 'win64 i32 %machine-ir-smoke.red [
	fail "while CFG function did not start"
]
rs-o2-ir/add-stack-object 'iterations 'argument i32 4 4 'none
rs-o2-ir/add-stack-object 'i 'local i32 4 4 'none
rs-o2-ir/set-stack-offset 'iterations -8
rs-o2-ir/set-stack-offset 'i -16
zero: rs-o2-ir/emit-constant 0 i32
rs-o2-ir/emit-store-local 'i zero i32
while-state: rs-o2-ir/begin-while
loop-i: rs-o2-ir/emit-load-local 'i i32
loop-limit: rs-o2-ir/emit-load-local 'iterations i32
loop-test: rs-o2-ir/emit-binary rs-o2-ir/less-op loop-i loop-limit logic-type 'pure
rs-o2-ir/while-condition while-state
loop-i: rs-o2-ir/emit-load-local 'i i32
one: rs-o2-ir/emit-constant 1 i32
loop-i: rs-o2-ir/emit-binary rs-o2-ir/add-op loop-i one i32 'pure
rs-o2-ir/emit-store-local 'i loop-i i32
rs-o2-ir/end-while while-state
loop-i: rs-o2-ir/emit-load-local 'i i32
rs-o2-ir/set-direct-body-range 0 1
while-selected: rs-o2-ir/finish-function reduce [#{90} copy []]
unless find while-selected/1 #{7D} [fail "while CFG short branch was not selected"]
unless find while-selected/1 #{EB} [fail "while CFG short back edge was not selected"]
unless find while-selected/1 #{448B4DF8} [fail "live-in promoted argument was not loaded"]
if find while-selected/1 #{448B45F0} [fail "definitely assigned local was loaded at entry"]
if find while-selected/1 #{0F9C} [fail "branch-only comparison materialized a logic value"]

unless rs-o2-ir/begin-function 'if-cfg 'win64 i32 %machine-ir-smoke.red [
	fail "if CFG function did not start"
]
rs-o2-ir/add-stack-object 'value 'argument i32 4 4 'none
rs-o2-ir/add-stack-object 'result 'local i32 4 4 'none
rs-o2-ir/set-stack-offset 'value -8
rs-o2-ir/set-stack-offset 'result -16
zero: rs-o2-ir/emit-constant 0 i32
rs-o2-ir/emit-store-local 'result zero i32
if-state: rs-o2-ir/begin-if
if-value: rs-o2-ir/emit-load-local 'value i32
four: rs-o2-ir/emit-constant 4 i32
if-test: rs-o2-ir/emit-binary rs-o2-ir/equal-op if-value four logic-type 'pure
rs-o2-ir/if-condition if-state
if-value: rs-o2-ir/emit-load-local 'value i32
rs-o2-ir/emit-store-local 'result if-value i32
rs-o2-ir/end-if if-state
if-result: rs-o2-ir/emit-load-local 'result i32
rs-o2-ir/set-direct-body-range 0 1
if-selected: rs-o2-ir/finish-function reduce [#{90} copy []]
unless any [
	find if-selected/1 #{83F804}
	find if-selected/1 #{83F904}
	find if-selected/1 #{83FA04}
	find if-selected/1 #{83FB04}
][fail "if immediate comparison was not selected"]
if find if-selected/1 #{E9} [fail "if trace layout emitted a redundant jump"]

unless rs-o2-ir/begin-function 'constant-if-cfg 'win64 i32 %machine-ir-smoke.red [
	fail "constant if CFG function did not start"
]
rs-o2-ir/add-stack-object 'result 'local i32 4 4 'none
rs-o2-ir/set-stack-offset 'result -8
constant-zero: rs-o2-ir/emit-constant 0 i32
rs-o2-ir/emit-store-local 'result constant-zero i32
constant-if-state: rs-o2-ir/begin-if
constant-three: rs-o2-ir/emit-constant 3 i32
constant-four: rs-o2-ir/emit-constant 4 i32
constant-test: rs-o2-ir/emit-binary rs-o2-ir/equal-op constant-three constant-four logic-type 'pure
rs-o2-ir/if-condition constant-if-state
constant-seven: rs-o2-ir/emit-constant 7 i32
rs-o2-ir/emit-store-local 'result constant-seven i32
rs-o2-ir/end-if constant-if-state
constant-result: rs-o2-ir/emit-load-local 'result i32
rs-o2-ir/set-direct-body-range 0 1
constant-if-selected: rs-o2-ir/finish-function reduce [#{90} copy []]

unless rs-o2-ir/begin-function 'long-if-cfg 'win64 i32 %machine-ir-smoke.red [
	fail "long if CFG function did not start"
]
rs-o2-ir/add-stack-object 'value 'argument i32 4 4 'none
rs-o2-ir/add-stack-object 'result 'local i32 4 4 'none
rs-o2-ir/set-stack-offset 'value -8
rs-o2-ir/set-stack-offset 'result -16
long-value: rs-o2-ir/emit-load-local 'value i32
rs-o2-ir/emit-store-local 'result long-value i32
long-if-state: rs-o2-ir/begin-if
long-zero: rs-o2-ir/emit-constant 0 i32
long-test: rs-o2-ir/emit-binary rs-o2-ir/equal-op long-value long-zero logic-type 'pure
rs-o2-ir/if-condition long-if-state
long-one: rs-o2-ir/emit-constant 1 i32
loop 64 [
	long-value: rs-o2-ir/emit-binary rs-o2-ir/add-op long-value long-one i32 'pure
]
rs-o2-ir/emit-store-local 'result long-value i32
rs-o2-ir/end-if long-if-state
long-result: rs-o2-ir/emit-load-local 'result i32
rs-o2-ir/set-direct-body-range 0 1
long-if-selected: rs-o2-ir/finish-function reduce [#{90} copy []]
unless find long-if-selected/1 #{0F85} [fail "long if CFG branch was incorrectly shortened"]

unless rs-o2-ir/begin-function 'memory-operand 'win64 i32 %machine-ir-smoke.red [
	fail "memory operand function did not start"
]
foreach [name offset] [
	a -8 b -16 c -24 d -32 e -40 f -48 g -56 h -64 i -72 j -80 k -88 result -96
][
	rs-o2-ir/add-stack-object name either name = 'result ['local]['argument] i32 4 4 'none
	rs-o2-ir/set-stack-offset name offset
]
memory-a: rs-o2-ir/emit-load-local 'a i32
memory-b: rs-o2-ir/emit-load-local 'b i32
memory-c: rs-o2-ir/emit-load-local 'c i32
rs-o2-ir/emit-store-local 'result memory-a i32
memory-if-state: rs-o2-ir/begin-if
memory-e: rs-o2-ir/emit-load-local 'e i32
memory-test: rs-o2-ir/emit-binary rs-o2-ir/equal-op memory-a memory-e logic-type 'pure
rs-o2-ir/if-condition memory-if-state
memory-d: rs-o2-ir/emit-load-local 'd i32
memory-f: rs-o2-ir/emit-load-local 'f i32
memory-sum: rs-o2-ir/emit-binary rs-o2-ir/add-op memory-d memory-f i32 'pure
rs-o2-ir/emit-store-local 'result memory-sum i32
memory-value: rs-o2-ir/emit-load-local 'result i32
memory-g: rs-o2-ir/emit-load-local 'g i32
memory-value: rs-o2-ir/emit-binary rs-o2-ir/subtract-op memory-value memory-g i32 'pure
rs-o2-ir/emit-store-local 'result memory-value i32
memory-value: rs-o2-ir/emit-load-local 'result i32
memory-h: rs-o2-ir/emit-load-local 'h i32
memory-value: rs-o2-ir/emit-binary 'and memory-value memory-h i32 'pure
rs-o2-ir/emit-store-local 'result memory-value i32
memory-value: rs-o2-ir/emit-load-local 'result i32
memory-i: rs-o2-ir/emit-load-local 'i i32
memory-value: rs-o2-ir/emit-binary 'or memory-value memory-i i32 'pure
rs-o2-ir/emit-store-local 'result memory-value i32
memory-value: rs-o2-ir/emit-load-local 'result i32
memory-j: rs-o2-ir/emit-load-local 'j i32
memory-value: rs-o2-ir/emit-binary 'xor memory-value memory-j i32 'pure
rs-o2-ir/emit-store-local 'result memory-value i32
memory-value: rs-o2-ir/emit-load-local 'result i32
memory-k: rs-o2-ir/emit-load-local 'k i32
memory-value: rs-o2-ir/emit-binary rs-o2-ir/multiply-op memory-value memory-k i32 'pure
rs-o2-ir/emit-store-local 'result memory-value i32
rs-o2-ir/end-if memory-if-state
memory-result: rs-o2-ir/emit-load-local 'result i32
rs-o2-ir/set-direct-body-range 0 1
memory-selected: rs-o2-ir/finish-function reduce [#{90} copy []]
unless any [
	find memory-selected/1 #{3B45D8}
	find memory-selected/1 #{3B4DD8}
	find memory-selected/1 #{3B55D8}
	find memory-selected/1 #{443B45D8}
	find memory-selected/1 #{443B4DD8}
	find memory-selected/1 #{443B55D8}
	find memory-selected/1 #{443B5DD8}
][fail "direct frame-memory comparison was not selected"]
unless any [
	find memory-selected/1 #{0345D0}
	find memory-selected/1 #{440345E0}
][fail "direct frame-memory add was not selected"]
unless find memory-selected/1 #{442B45C8} [fail "direct frame-memory subtract was not selected"]
unless find memory-selected/1 #{442345C0} [fail "direct frame-memory and was not selected"]
unless find memory-selected/1 #{440B45B8} [fail "direct frame-memory or was not selected"]
unless find memory-selected/1 #{443345B0} [fail "direct frame-memory xor was not selected"]
unless find memory-selected/1 #{440FAF45A8} [fail "direct frame-memory multiply was not selected"]

unless rs-o2-ir/begin-function 'memory-left-immediate 'win64 i32 %machine-ir-smoke.red [
	fail "memory plus immediate function did not start"
]
rs-o2-ir/add-stack-object 'value 'local i32 4 4 'none
rs-o2-ir/set-stack-offset 'value -8
rs-o2-ir/set-source %machine-ir-smoke.red 10
memory-immediate-value: rs-o2-ir/emit-load-local 'value i32
memory-immediate-one: rs-o2-ir/emit-constant 1 i32
memory-immediate-result: rs-o2-ir/emit-binary rs-o2-ir/add-op memory-immediate-value memory-immediate-one i32 'pure
rs-o2-ir/set-source %machine-ir-smoke.red 20
memory-immediate-two: rs-o2-ir/emit-constant 2 i32
memory-immediate-result: rs-o2-ir/emit-binary rs-o2-ir/add-op memory-immediate-result memory-immediate-two i32 'pure
rs-o2-ir/set-direct-body-range 2 4
smoke-debug-files: make hash! 4
append smoke-debug-files %machine-ir-smoke.red
smoke-debug-lines: reduce [
	'records reduce [102 10 1 103 20 1]
	'files smoke-debug-files
]
rs-o2-ir/debug?: yes
memory-immediate-selected: rs-o2-ir/finish-function/debug
	reduce [#{90909090C3} copy [] 100]
	smoke-debug-lines
rs-o2-ir/debug?: no
unless find memory-immediate-selected/1 #{8B45F883C001} [
	fail "frame-memory plus immediate used an uninitialized register"
]
unless smoke-debug-lines/2 = reduce [102 10 1 108 20 1] [
	fail rejoin [
		"optimized debug offsets were not rewritten: "
		mold/flat smoke-debug-lines/2
		" bytes=" mold memory-immediate-selected/1
	]
]

unless rs-o2-ir/begin-function 'float-memory-operand 'win64 f64 %machine-ir-smoke.red [
	fail "float memory operand function did not start"
]
foreach [name kind type size offset] [
	condition argument i32 4 -8
	a argument f64 8 -16
	b argument f64 8 -24
	result local f64 8 -32
][
	rs-o2-ir/add-stack-object name kind (get type) size size 'none
	rs-o2-ir/set-stack-offset name offset
]
float-memory-a: rs-o2-ir/emit-load-local 'a f64
rs-o2-ir/emit-store-local 'result float-memory-a f64
float-memory-if: rs-o2-ir/begin-if
float-memory-condition: rs-o2-ir/emit-load-local 'condition i32
float-memory-zero: rs-o2-ir/emit-constant 0 i32
float-memory-test: rs-o2-ir/emit-binary rs-o2-ir/greater-op float-memory-condition float-memory-zero logic-type 'pure
rs-o2-ir/if-condition float-memory-if
float-memory-left: rs-o2-ir/emit-load-local 'result f64
float-memory-right: rs-o2-ir/emit-load-local 'b f64
float-memory-sum: rs-o2-ir/emit-binary rs-o2-ir/add-op float-memory-left float-memory-right f64 'pure
rs-o2-ir/emit-store-local 'result float-memory-sum f64
rs-o2-ir/end-if float-memory-if
float-memory-left: rs-o2-ir/emit-load-local 'result f64
float-memory-right: rs-o2-ir/emit-load-local 'b f64
float-memory-result: rs-o2-ir/emit-binary rs-o2-ir/multiply-op float-memory-left float-memory-right f64 'pure
rs-o2-ir/set-direct-body-range 0 1
float-memory-selected: rs-o2-ir/finish-function reduce [#{90} copy []]
unless any [
	find float-memory-selected/1 #{F20F5845E8}
	find float-memory-selected/1 #{F20F5845E0}
][fail "direct frame-memory float add was not selected"]
unless any [
	find float-memory-selected/1 #{F20F5945E8}
	find float-memory-selected/1 #{F20F5945E0}
][fail "direct frame-memory float multiply was not selected"]

unless rs-o2-ir/begin-function 'integer-spill 'win64 i32 %machine-ir-smoke.red [
	fail "integer spill function did not start"
]
integer-spill-values: make block! 8
foreach [name offset] [a -8 b -16 c -24 d -32 e -40 f -48 g -56 h -64][
	rs-o2-ir/add-stack-object name 'local i32 4 4 'none
	rs-o2-ir/set-stack-offset name offset
	append integer-spill-values rs-o2-ir/emit-load-local name i32
]
integer-spill-left: integer-spill-values/1
foreach integer-spill-value next integer-spill-values [
	integer-spill-left: rs-o2-ir/emit-binary rs-o2-ir/subtract-op integer-spill-left integer-spill-value i32 'pure
]
integer-spill-right: integer-spill-values/1
foreach integer-spill-value next integer-spill-values [
	integer-spill-right: rs-o2-ir/emit-binary rs-o2-ir/add-op integer-spill-right integer-spill-value i32 'pure
]
integer-spill-result: rs-o2-ir/emit-binary rs-o2-ir/add-op integer-spill-left integer-spill-right i32 'pure
rs-o2-ir/set-direct-body-range 0 1
integer-spill-selected: rs-o2-ir/finish-function reduce [#{90} copy []]
unless any [
	find integer-spill-selected/1 #{4883EC}
	find integer-spill-selected/1 #{4881EC}
][fail "integer spill frame was not reserved"]
unless find integer-spill-selected/1 #{44895D} [fail "integer spill store was not emitted"]
unless all [
	rs-o2-x64/spill-gpr-scratch = 'r11d
	(length? rs-o2-x64/spilled-values) >= 4
][fail "integer spill allocation metadata is wrong"]

unless rs-o2-ir/begin-function 'float-spill 'win64 f64 %machine-ir-smoke.red [
	fail "float spill function did not start"
]
float-spill-values: make block! 8
foreach [name offset] [a -8 b -16 c -24 d -32 e -40 f -48 g -56][
	rs-o2-ir/add-stack-object name 'local f64 8 8 'none
	rs-o2-ir/set-stack-offset name offset
	append float-spill-values rs-o2-ir/emit-load-local name f64
]
float-spill-left: float-spill-values/1
foreach float-spill-value next float-spill-values [
	float-spill-left: rs-o2-ir/emit-binary rs-o2-ir/subtract-op float-spill-left float-spill-value f64 'pure
]
float-spill-right: float-spill-values/1
foreach float-spill-value next float-spill-values [
	float-spill-right: rs-o2-ir/emit-binary rs-o2-ir/add-op float-spill-right float-spill-value f64 'pure
]
float-spill-result: rs-o2-ir/emit-binary rs-o2-ir/add-op float-spill-left float-spill-right f64 'pure
rs-o2-ir/set-direct-body-range 0 1
float-spill-selected: rs-o2-ir/finish-function reduce [#{90} copy []]
unless any [
	find float-spill-selected/1 #{4883EC}
	find float-spill-selected/1 #{4881EC}
][fail "float spill frame was not reserved"]
unless find float-spill-selected/1 #{F20F116D} [fail "float spill store was not emitted"]
if find float-spill-selected/1 #{F20F58C0} [fail "float spill result overwrote its right operand"]
unless all [
	rs-o2-x64/spill-xmm-scratch = 'xmm5
	(length? rs-o2-x64/spilled-values) >= 4
][fail "float spill allocation metadata is wrong"]

unless rs-o2-ir/begin-function 'call-wrapper 'win64 i32 %machine-ir-smoke.red [
	fail "call wrapper function did not start"
]
rs-o2-ir/add-stack-object 'a 'argument i32 4 4 'none
rs-o2-ir/add-stack-object 'b 'argument i32 4 4 'none
rs-o2-ir/set-stack-offset 'a -8
rs-o2-ir/set-stack-offset 'b -16
call-a: rs-o2-ir/emit-load-local 'a i32
call-b: rs-o2-ir/emit-load-local 'b i32
call-result: rs-o2-ir/emit-call 'callee reduce [call-a call-b] i32
rs-o2-ir/set-direct-body-range 0 5
callee-relocs: reduce [101]
put emitter/symbols 'callee reduce ['native none callee-relocs]
call-selected: rs-o2-ir/finish-function reduce [#{E800000000} reduce [callee-relocs] 100]
unless call-selected/1 = #{8B4DF88B55F0E800000000} [fail "Win64 direct call bytes are wrong"]
unless callee-relocs/1 = 107 [fail "direct call relocation was not moved"]

unless rs-o2-ir/begin-function 'float-call-wrapper 'win64 f64 %machine-ir-smoke.red [
	fail "float call wrapper function did not start"
]
rs-o2-ir/add-stack-object 'a 'argument f64 8 8 'none
rs-o2-ir/add-stack-object 'b 'argument f64 8 8 'none
rs-o2-ir/set-stack-offset 'a -8
rs-o2-ir/set-stack-offset 'b -16
float-call-a: rs-o2-ir/emit-load-local 'a f64
float-call-b: rs-o2-ir/emit-load-local 'b f64
float-call-result: rs-o2-ir/emit-call 'float-callee reduce [float-call-a float-call-b] f64
rs-o2-ir/set-direct-body-range 0 5
float-callee-relocs: reduce [401]
put emitter/symbols 'float-callee reduce ['native none float-callee-relocs]
float-call-selected: rs-o2-ir/finish-function reduce [#{E800000000} reduce [float-callee-relocs] 400]
unless float-call-selected/1 = #{F20F1045F8F20F104DF0E800000000} [
	fail rejoin ["Win64 direct float call bytes are wrong: " mold float-call-selected/1]
]
unless float-callee-relocs/1 = 411 [fail "direct float call relocation was not moved"]

unless rs-o2-ir/begin-function 'promoted-call-cfg 'win64 i32 %machine-ir-smoke.red [
	fail "promoted call CFG function did not start"
]
rs-o2-ir/add-stack-object 'limit 'argument i32 4 4 'none
rs-o2-ir/add-stack-object 'i 'local i32 4 4 'none
rs-o2-ir/set-stack-offset 'limit -8
rs-o2-ir/set-stack-offset 'i -16
promoted-zero: rs-o2-ir/emit-constant 0 i32
rs-o2-ir/emit-store-local 'i promoted-zero i32
promoted-while-state: rs-o2-ir/begin-while
promoted-i: rs-o2-ir/emit-load-local 'i i32
promoted-limit: rs-o2-ir/emit-load-local 'limit i32
promoted-test: rs-o2-ir/emit-binary rs-o2-ir/less-op promoted-i promoted-limit logic-type 'pure
rs-o2-ir/while-condition promoted-while-state
promoted-live-i: rs-o2-ir/emit-load-local 'i i32
promoted-call-i: rs-o2-ir/emit-load-local 'i i32
promoted-call-result: rs-o2-ir/emit-call 'promoted-callee reduce [promoted-call-i] i32
promoted-next-i: rs-o2-ir/emit-binary rs-o2-ir/add-op promoted-live-i promoted-call-result i32 'pure
rs-o2-ir/emit-store-local 'i promoted-next-i i32
rs-o2-ir/end-while promoted-while-state
promoted-result: rs-o2-ir/emit-load-local 'i i32
rs-o2-ir/set-direct-body-range 0 5
promoted-callee-relocs: reduce [301]
put emitter/symbols 'promoted-callee reduce ['native none promoted-callee-relocs]
promoted-call-selected: rs-o2-ir/finish-function reduce [
	#{E800000000} reduce [promoted-callee-relocs] 300
]
unless find promoted-call-selected/1 #{4489C1} [fail "promoted call argument move was not selected"]
unless find promoted-call-selected/1 #{448945F0} [fail "promoted local was not flushed before call"]
unless find promoted-call-selected/1 #{448B45F0} [fail "promoted local was not reloaded after call"]
unless promoted-callee-relocs/1 > 301 [fail "promoted call relocation was not moved"]

unless rs-o2-ir/begin-function 'sysv-call-wrapper 'sysv i32 %machine-ir-smoke.red [
	fail "SysV call wrapper function did not start"
]
rs-o2-ir/add-stack-object 'a 'argument i32 4 4 'none
rs-o2-ir/add-stack-object 'b 'argument i32 4 4 'none
rs-o2-ir/set-stack-offset 'a -8
rs-o2-ir/set-stack-offset 'b -16
sysv-call-a: rs-o2-ir/emit-load-local 'a i32
sysv-call-b: rs-o2-ir/emit-load-local 'b i32
sysv-call-result: rs-o2-ir/emit-call 'sysv-callee reduce [sysv-call-a sysv-call-b] i32
rs-o2-ir/set-direct-body-range 0 5
sysv-callee-relocs: reduce [201]
put emitter/symbols 'sysv-callee reduce ['native none sysv-callee-relocs]
sysv-call-selected: rs-o2-ir/finish-function reduce [#{E800000000} reduce [sysv-callee-relocs] 200]
unless sysv-call-selected/1 = #{8B7DF88B75F0E800000000} [fail "SysV direct call bytes are wrong"]
unless sysv-callee-relocs/1 = 207 [fail "SysV direct call relocation was not moved"]

unless rs-o2-ir/begin-function 'sysv-mixed-call-wrapper 'sysv f64 %machine-ir-smoke.red [
	fail "SysV mixed call wrapper function did not start"
]
rs-o2-ir/add-stack-object 'tag 'argument i32 4 4 'none
rs-o2-ir/add-stack-object 'value 'argument f64 8 8 'none
rs-o2-ir/set-stack-offset 'tag -8
rs-o2-ir/set-stack-offset 'value -16
sysv-mixed-tag: rs-o2-ir/emit-load-local 'tag i32
sysv-mixed-value: rs-o2-ir/emit-load-local 'value f64
sysv-mixed-result: rs-o2-ir/emit-call 'sysv-mixed-callee reduce [sysv-mixed-tag sysv-mixed-value] f64
rs-o2-ir/set-direct-body-range 0 5
sysv-mixed-relocs: reduce [501]
put emitter/symbols 'sysv-mixed-callee reduce ['native none sysv-mixed-relocs]
sysv-mixed-selected: rs-o2-ir/finish-function reduce [#{E800000000} reduce [sysv-mixed-relocs] 500]
unless sysv-mixed-selected/1 = #{8B7DF8F20F1045F0E800000000} [
	fail "SysV mixed direct call bytes are wrong"
]
unless sysv-mixed-relocs/1 = 509 [fail "SysV mixed call relocation was not moved"]

unless rs-o2-ir/begin-function 'win64-five-integer-call 'win64 i32 %machine-ir-smoke.red [
	fail "Win64 five-integer call function did not start"
]
win64-five-values: make block! 5
foreach [name offset] [a -8 b -16 c -24 d -32 e -40][
	rs-o2-ir/add-stack-object name 'argument i32 4 4 'none
	rs-o2-ir/set-stack-offset name offset
	append win64-five-values rs-o2-ir/emit-load-local name i32
]
win64-five-result: rs-o2-ir/emit-call 'win64-five-callee win64-five-values i32
rs-o2-ir/set-direct-body-range 0 5
win64-five-relocs: reduce [701]
put emitter/symbols 'win64-five-callee reduce ['native none win64-five-relocs]
win64-five-selected: rs-o2-ir/finish-function reduce [
	#{E800000000} reduce [win64-five-relocs] 700
]
unless find win64-five-selected/1 #{4883EC30} [fail "Win64 outgoing call area was not reserved once"]
unless find win64-five-selected/1 #{89442420} [
	fail rejoin ["Win64 fifth integer argument was not stored on the stack: " mold win64-five-selected/1]
]
unless all [
	rs-o2-x64/outgoing-frame-bytes = 48
	rs-o2-x64/spill-frame-bytes = 48
][fail "Win64 outgoing frame metadata is wrong"]
unless win64-five-relocs/1 > 701 [fail "Win64 five-argument relocation was not moved"]

unless rs-o2-ir/begin-function 'win64-five-mixed-call 'win64 f64 %machine-ir-smoke.red [
	fail "Win64 mixed stack-float call function did not start"
]
win64-mixed-values: make block! 5
foreach [name offset] [a -8 b -16 c -24 d -32][
	rs-o2-ir/add-stack-object name 'argument i32 4 4 'none
	rs-o2-ir/set-stack-offset name offset
	append win64-mixed-values rs-o2-ir/emit-load-local name i32
]
rs-o2-ir/add-stack-object 'e 'argument f64 8 8 'none
rs-o2-ir/set-stack-offset 'e -40
append win64-mixed-values rs-o2-ir/emit-load-local 'e f64
win64-mixed-result: rs-o2-ir/emit-call 'win64-mixed-callee win64-mixed-values f64
rs-o2-ir/set-direct-body-range 0 5
win64-mixed-relocs: reduce [801]
put emitter/symbols 'win64-mixed-callee reduce ['native none win64-mixed-relocs]
win64-mixed-selected: rs-o2-ir/finish-function reduce [
	#{E800000000} reduce [win64-mixed-relocs] 800
]
unless find win64-mixed-selected/1 #{F20F11442420} [
	fail rejoin ["Win64 fifth float argument was not stored on the stack: " mold win64-mixed-selected/1]
]
unless win64-mixed-relocs/1 > 801 [fail "Win64 mixed five-argument relocation was not moved"]

unless rs-o2-ir/begin-function 'sysv-seven-integer-call 'sysv i32 %machine-ir-smoke.red [
	fail "SysV seven-integer call function did not start"
]
sysv-seven-values: make block! 7
foreach [name offset] [a -8 b -16 c -24 d -32 e -40 f -48 g -56][
	rs-o2-ir/add-stack-object name 'argument i32 4 4 'none
	rs-o2-ir/set-stack-offset name offset
	append sysv-seven-values rs-o2-ir/emit-load-local name i32
]
sysv-seven-result: rs-o2-ir/emit-call 'sysv-seven-callee sysv-seven-values i32
rs-o2-ir/set-direct-body-range 0 5
sysv-seven-relocs: reduce [901]
put emitter/symbols 'sysv-seven-callee reduce ['native none sysv-seven-relocs]
sysv-seven-selected: rs-o2-ir/finish-function reduce [
	#{E800000000} reduce [sysv-seven-relocs] 900
]
unless find sysv-seven-selected/1 #{4883EC10} [fail "SysV outgoing call area was not reserved once"]
unless find sysv-seven-selected/1 #{890424} [
	fail rejoin ["SysV seventh integer argument was not stored on the stack: " mold sysv-seven-selected/1]
]
unless all [
	rs-o2-x64/outgoing-frame-bytes = 16
	rs-o2-x64/spill-frame-bytes = 16
][fail "SysV outgoing frame metadata is wrong"]
unless sysv-seven-relocs/1 > 901 [fail "SysV seven-argument relocation was not moved"]

unless rs-o2-ir/begin-function 'sysv-nine-float-call 'sysv f64 %machine-ir-smoke.red [
	fail "SysV nine-float call function did not start"
]
sysv-nine-float-values: make block! 9
foreach [name offset] [
	a -8 b -16 c -24 d -32 e -40 f -48 g -56 h -64 i -72
][
	rs-o2-ir/add-stack-object name 'argument f64 8 8 'none
	rs-o2-ir/set-stack-offset name offset
	append sysv-nine-float-values rs-o2-ir/emit-load-local name f64
]
sysv-nine-float-result: rs-o2-ir/emit-call 'sysv-nine-float-callee sysv-nine-float-values f64
rs-o2-ir/set-direct-body-range 0 5
sysv-nine-float-relocs: reduce [1001]
put emitter/symbols 'sysv-nine-float-callee reduce ['native none sysv-nine-float-relocs]
sysv-nine-float-selected: rs-o2-ir/finish-function reduce [
	#{E800000000} reduce [sysv-nine-float-relocs] 1000
]
unless find sysv-nine-float-selected/1 #{4883EC10} [
	fail "SysV nine-float outgoing call area was not reserved once"
]
unless find sysv-nine-float-selected/1 #{F2440F110424} [
	fail rejoin ["SysV ninth float argument did not use XMM8: " mold sysv-nine-float-selected/1]
]
unless all [
	rs-o2-x64/outgoing-frame-bytes = 16
	rs-o2-x64/spill-frame-bytes = 16
][fail "SysV nine-float outgoing frame metadata is wrong"]
unless sysv-nine-float-relocs/1 > 1001 [fail "SysV nine-float relocation was not moved"]

unless rs-o2-ir/begin-function 'live-value-across-call 'win64 i32 %machine-ir-smoke.red [
	fail "live-value-across-call function did not start"
]
rs-o2-ir/add-stack-object 'value 'argument i32 4 4 'none
rs-o2-ir/set-stack-offset 'value -8
live-call-value: rs-o2-ir/emit-load-local 'value i32
live-call-result: rs-o2-ir/emit-call 'live-call-callee copy [] i32
live-call-sum: rs-o2-ir/emit-binary rs-o2-ir/add-op live-call-value live-call-result i32 'pure
rs-o2-ir/set-direct-body-range 0 5
live-call-relocs: reduce [1101]
put emitter/symbols 'live-call-callee reduce ['native none live-call-relocs]
live-call-selected: rs-o2-ir/finish-function reduce [
	#{E800000000} reduce [live-call-relocs] 1100
]
unless rs-o2-x64/call-spilled-values = reduce [live-call-value] [
	fail rejoin ["live value was not planned as a call spill: " mold rs-o2-x64/call-spilled-values]
]
unless find live-call-selected/1 #{4883EC40} [fail "live call spill frame was not reserved"]
unless find live-call-selected/1 #{44895DB0} [fail "live value was not stored before the call"]
unless find live-call-selected/1 #{448B5DB0} [fail "live value was not reloaded after the call"]
unless live-call-relocs/1 > 1101 [fail "live-value call relocation was not moved"]

unless rs-o2-ir/begin-function 'call-result-across-call 'win64 i32 %machine-ir-smoke.red [
	fail "call-result-across-call function did not start"
]
first-live-result: rs-o2-ir/emit-call 'first-live-callee copy [] i32
second-live-result: rs-o2-ir/emit-call 'second-live-callee copy [] i32
combined-live-result: rs-o2-ir/emit-binary rs-o2-ir/add-op first-live-result second-live-result i32 'pure
rs-o2-ir/set-direct-body-range 0 10
first-live-relocs: reduce [1201]
second-live-relocs: reduce [1206]
put emitter/symbols 'first-live-callee reduce ['native none first-live-relocs]
put emitter/symbols 'second-live-callee reduce ['native none second-live-relocs]
two-call-selected: rs-o2-ir/finish-function reduce [
	#{E800000000E800000000} reduce [first-live-relocs second-live-relocs] 1200
]
unless rs-o2-x64/call-spilled-values = reduce [first-live-result] [
	fail rejoin ["first call result was not planned as a spill: " mold rs-o2-x64/call-spilled-values]
]
unless find two-call-selected/1 #{8945B0} [fail "first call result was not stored after the call"]
unless find two-call-selected/1 #{448B5DB0} [fail "first call result was not reloaded after the second call"]
unless all [first-live-relocs/1 > 1201 second-live-relocs/1 > 1206] [
	fail "two-call relocations were not moved"
]

unless rs-o2-ir/begin-function 'nested-call-result 'win64 i32 %machine-ir-smoke.red [
	fail "nested-call-result function did not start"
]
nested-inner-result: rs-o2-ir/emit-call 'nested-inner-callee copy [] i32
nested-outer-result: rs-o2-ir/emit-call 'nested-outer-callee reduce [nested-inner-result] i32
rs-o2-ir/set-direct-body-range 0 10
nested-inner-relocs: reduce [1301]
nested-outer-relocs: reduce [1306]
put emitter/symbols 'nested-inner-callee reduce ['native none nested-inner-relocs]
put emitter/symbols 'nested-outer-callee reduce ['native none nested-outer-relocs]
nested-call-selected: rs-o2-ir/finish-function reduce [
	#{E800000000E800000000} reduce [nested-inner-relocs nested-outer-relocs] 1300
]
unless find nested-call-selected/1 #{89C1E8} [
	fail rejoin ["nested call result was not moved from eax to ecx: " mold nested-call-selected/1]
]
unless empty? rs-o2-x64/call-spilled-values [fail "nested call result was unnecessarily spilled"]
unless all [nested-inner-relocs/1 = 1301 nested-outer-relocs/1 = 1308] [
	fail rejoin [
		"nested-call relocations are wrong: "
		mold reduce [nested-inner-relocs/1 nested-outer-relocs/1]
	]
]

unless rs-o2-ir/begin-function 'register-arguments-after-call 'win64 i32 %machine-ir-smoke.red [
	fail "register-arguments-after-call function did not start"
]
rs-o2-ir/add-stack-object 'integer-value 'argument i32 4 4 'none
rs-o2-ir/set-stack-offset 'integer-value -8
rs-o2-ir/add-stack-object 'float-value 'argument f64 8 8 'none
rs-o2-ir/set-stack-offset 'float-value -16
live-register-integer: rs-o2-ir/emit-load-local 'integer-value i32
live-register-float: rs-o2-ir/emit-load-local 'float-value f64
rs-o2-ir/emit-call 'register-clobber-callee copy [] none
register-argument-result: rs-o2-ir/emit-call
	'register-consumer-callee
	reduce [live-register-integer live-register-float]
	i32
rs-o2-ir/set-direct-body-range 0 10
register-clobber-relocs: reduce [1401]
register-consumer-relocs: reduce [1406]
put emitter/symbols 'register-clobber-callee reduce ['native none register-clobber-relocs]
put emitter/symbols 'register-consumer-callee reduce ['native none register-consumer-relocs]
register-argument-selected: rs-o2-ir/finish-function reduce [
	#{E800000000E800000000}
	reduce [register-clobber-relocs register-consumer-relocs]
	1400
]
unless rs-o2-x64/call-spilled-values = reduce [live-register-integer live-register-float] [
	fail rejoin [
		"register arguments were not preserved across the call: "
		mold rs-o2-x64/call-spilled-values
	]
]
unless find register-argument-selected/1 #{8B4DB0F20F104DA8E8} [
	fail rejoin [
		"spilled register arguments were not loaded into ECX/XMM1: "
		mold register-argument-selected/1
	]
]
unless all [register-clobber-relocs/1 > 1401 register-consumer-relocs/1 > 1406] [
	fail "register-argument call relocations were not moved"
]

clear emitter/bits-buf
foreach bitmap-word [1 0 1 0] [
	append emitter/bits-buf int-to-bin/to-bin32 bitmap-word
]
unless rs-o2-ir/begin-function 'gc-pointer-across-call 'win64 i32 %machine-ir-smoke.red [
	fail "gc-pointer-across-call function did not start"
]
rs-o2-ir/set-frame-bitmap-offset 0
rs-o2-ir/add-stack-object 'pointer-value 'argument ptr-type 8 8 'pointer
rs-o2-ir/set-stack-offset 'pointer-value -40
gc-live-pointer: rs-o2-ir/emit-load-local 'pointer-value ptr-type
gc-inner-result: rs-o2-ir/emit-call 'gc-clobber-callee copy [] i32
gc-outer-result: rs-o2-ir/emit-call
	'gc-consumer-callee
	reduce [gc-live-pointer gc-inner-result]
	i32
rs-o2-ir/set-direct-body-range 15 25
gc-clobber-relocs: reduce [1616]
gc-consumer-relocs: reduce [1621]
put emitter/symbols 'gc-clobber-callee reduce ['native none gc-clobber-relocs]
put emitter/symbols 'gc-consumer-callee reduce ['native none gc-consumer-relocs]
gc-selected: rs-o2-ir/finish-function reduce [
	#{554889E56A006A0068000000006A00E800000000E800000000C9C3}
	reduce [gc-clobber-relocs gc-consumer-relocs]
	1600
]
unless (copy/part at gc-selected/1 10 4) = #{04000000} [
	fail rejoin ["GC bitmap prologue offset was not patched: " mold gc-selected/1]
]
unless (copy skip emitter/bits-buf 16) = #{01000000060000000100000020000000} [
	fail rejoin ["extended GC bitmap is wrong: " mold emitter/bits-buf]
]
unless rs-o2-x64/gc-bitmap-list = [1 6 1 - 32] [
	fail rejoin ["planned GC bitmap is wrong: " mold rs-o2-x64/gc-bitmap-list]
]
unless rs-o2-x64/gc-bitmap-offset = 4 [fail "GC bitmap word offset is wrong"]
unless rs-o2-x64/call-spilled-values = reduce [gc-live-pointer] [
	fail "managed pointer was not spilled across the call"
]

unless rs-o2-ir/begin-function 'fallback 'win64 none %machine-ir-smoke.red [
	fail "fallback function did not start"
]
rs-o2-ir/emit-opaque 'unsupported-smoke none
fallback-direct: reduce [#{CC} copy []]
fallback-selected: rs-o2-ir/finish-function fallback-direct
unless fallback-selected/1 = #{CC} [fail "fallback bytes changed"]
unless (pick rs-o2-ir/stats rs-o2-ir/stats-functions) = 35 [fail "final function count"]
unless (pick rs-o2-ir/stats rs-o2-ir/stats-verified) = 35 [fail "final verification count"]
unless (pick rs-o2-ir/stats rs-o2-ir/stats-eligible) = 34 [fail "final eligibility count"]
unless (pick rs-o2-ir/stats rs-o2-ir/stats-selected) = 34 [fail "final selection count"]
unless (pick rs-o2-ir/stats rs-o2-ir/stats-fallback) = 1 [fail "final fallback count"]

rs-o2-ir/end-session
dump-text: read dump-path
unless find dump-text "passes:" [fail "pass log missing"]
unless find dump-text "dead-local-stores 6 5" [fail "dead local store was not removed"]
unless find dump-text "dead-code-elimination 5 2" [fail "dead code was not removed"]
unless find dump-text "%3:i32 = const 3" [fail "constant expression was not folded"]
unless find dump-text "unreachable-blocks 11 8" [fail "constant branch block was not removed"]
unless find dump-text "dead-code-elimination 8 5" [fail "constant branch compare was not removed"]
print "machine-ir-smoke-ok"
