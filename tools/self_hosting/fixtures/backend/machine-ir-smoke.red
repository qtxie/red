Red [
	Title: "Machine IR construction and verifier smoke test"
]

#include %../../../../compiler/int-to-bin.red
#include %../../../../compiler/ieee-754.red
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
i8: rs-o2-ir/make-type 'i8 1 'gpr no 0 'none
i16: rs-o2-ir/make-type 'i16 2 'gpr no 0 'none
signed-i8: rs-o2-ir/make-type 'i8 1 'gpr yes 0 'none
signed-i16: rs-o2-ir/make-type 'i16 2 'gpr yes 0 'none
f32: rs-o2-ir/make-type 'f32 4 'xmm yes 0 'none
f64: rs-o2-ir/make-type 'f64 8 'xmm yes 0 'none
i64: rs-o2-ir/make-type 'i64 8 'gpr yes 0 'none
handle-type: rs-o2-ir/make-type 'i32 4 'gpr yes 0 'handle
ptr-type: rs-o2-ir/make-type 'ptr 8 'gpr no 4 'pointer
byte-ptr-type: rs-o2-ir/make-type 'ptr 8 'gpr no 1 'pointer
cell-ptr-type: rs-o2-ir/make-type 'ptr 8 'gpr no 16 'pointer
logic-type: rs-o2-ir/make-type 'logic 4 'gpr no 0 'none
logic-memory-bytes: make binary! 32
rs-o2-x64/emit-rip-load logic-memory-bytes logic-type 'r8d
rs-o2-x64/emit-rip-store logic-memory-bytes logic-type 'r8d
rs-o2-x64/emit-gpr-pointer-load logic-memory-bytes logic-type 'r8d 'r11d 0
rs-o2-x64/emit-gpr-pointer-store logic-memory-bytes logic-type 'r11d 0 'r8d
unless logic-memory-bytes = #{440FB6050000000044880500000000450FB603458803} [
	fail rejoin ["logic memory bytes are wrong: " mold logic-memory-bytes]
]
narrow-memory-bytes: make binary! 80
rs-o2-x64/emit-gpr-frame-load narrow-memory-bytes i8 'r8d -8
rs-o2-x64/emit-gpr-frame-load narrow-memory-bytes signed-i8 'r9d -16
rs-o2-x64/emit-gpr-frame-store narrow-memory-bytes i8 -24 'esi
rs-o2-x64/emit-gpr-frame-store narrow-memory-bytes i16 -32 'r9d
rs-o2-x64/emit-gpr-pointer-load narrow-memory-bytes i8 'r10d 'r11d 0
rs-o2-x64/emit-gpr-pointer-load narrow-memory-bytes signed-i16 'eax 'r12d 2
rs-o2-x64/emit-rip-load narrow-memory-bytes signed-i8 'r10d
rs-o2-x64/emit-rip-store narrow-memory-bytes i16 'esi
unless narrow-memory-bytes = #{440FB645F8440FBE4DF0408875E86644894DE0450FB613410FBF442402440FBE150000000066893500000000} [
	fail rejoin ["narrow memory bytes are wrong: " mold narrow-memory-bytes]
]
narrow-conversion-bytes: make binary! 16
rs-o2-x64/emit-normalize-narrow-register narrow-conversion-bytes i8 'r8d 'esi
rs-o2-x64/emit-normalize-narrow-register narrow-conversion-bytes signed-i16 'eax 'r9d
unless narrow-conversion-bytes = #{440FB6C6410FBFC1} [
	fail rejoin ["narrow conversion bytes are wrong: " mold narrow-conversion-bytes]
]
unless (rs-o2-x64/gpr-condition-code rs-o2-ir/greater-op i8) = 7 [
	fail "unsigned narrow comparison did not select JA"
]
unless (rs-o2-x64/gpr-condition-code rs-o2-ir/greater-op signed-i8) = 15 [
	fail "signed narrow comparison did not select JG"
]
frame-pointer-index-bytes: make binary! 8
unless rs-o2-x64/emit-movsxd-frame frame-pointer-index-bytes 'r11d -48 [
	fail "frame pointer index encoding failed"
]
unless frame-pointer-index-bytes = #{4C635DD0} [
	fail rejoin ["frame pointer index bytes are wrong: " mold frame-pointer-index-bytes]
]
frame-pointer-compare-bytes: make binary! 8
rs-o2-x64/emit-compare-memory frame-pointer-compare-bytes yes 'r8d -40
unless frame-pointer-compare-bytes = #{4C3B45D8} [
	fail rejoin ["frame pointer compare bytes are wrong: " mold frame-pointer-compare-bytes]
]
extended-xmm-bytes: make binary! 32
rs-o2-x64/emit-xmm-move extended-xmm-bytes f64 'xmm8 'xmm9
rs-o2-x64/emit-xmm-frame-load extended-xmm-bytes f64 'xmm10 -8
rs-o2-x64/emit-xmm-binary extended-xmm-bytes f64 rs-o2-ir/add-op 'xmm8 'xmm8 'xmm9
unless extended-xmm-bytes = #{F2450F10C1F2440F1055F8F2450F58C1} [
	fail rejoin ["extended XMM REX bytes are wrong: " mold extended-xmm-bytes]
]

float-constant-bytes: make binary! 32
unless rs-o2-x64/emit-float-constant float-constant-bytes 'xmm9 1.5 f32 [
	fail "f32 constant encoding failed"
]
unless rs-o2-x64/emit-float-constant float-constant-bytes 'xmm10 -0.0 f64 [
	fail "f64 constant encoding failed"
]
unless float-constant-bytes = #{41BB0000C03F66450F6ECB49BB0000000000000080664D0F6ED3} [
	fail rejoin ["float constant bytes are wrong: " mold float-constant-bytes]
]

integer-constant-bits: make binary! 24
rs-o2-x64/emit-mov-immediate integer-constant-bits 'r10d #{FFFFFFFF}
rs-o2-x64/emit-mov-immediate-wide integer-constant-bits 'r9d #{FFFFFFFF00000000}
unless integer-constant-bits = #{41BAFFFFFFFF49B9FFFFFFFF00000000} [
	fail rejoin ["integer constant bit encodings are wrong: " mold integer-constant-bits]
]

atomic-encoding-bytes: make binary! 64
foreach operation [add sub or xor and] [
	unless rs-o2-x64/emit-atomic-memory-register
		atomic-encoding-bytes operation 'r11d 'r10d
	[
		fail rejoin ["atomic " operation " register encoding failed"]
	]
]
unless rs-o2-x64/emit-atomic-xadd atomic-encoding-bytes 'r11d 'eax [
	fail "atomic XADD encoding failed"
]
unless rs-o2-x64/emit-atomic-cmpxchg atomic-encoding-bytes 'r11d 'r10d [
	fail "atomic CMPXCHG encoding failed"
]
unless rs-o2-x64/emit-neg-register atomic-encoding-bytes 'eax [
	fail "atomic subtraction NEG encoding failed"
]
unless atomic-encoding-bytes = #{F0450113F0452913F0450913F0453113F0452113F0410FC103F0450FB113F7D8} [
	fail rejoin ["atomic instruction encodings are wrong: " mold atomic-encoding-bytes]
]

float-conversion-bytes: make binary! 32
unless rs-o2-x64/emit-scalar-conversion float-conversion-bytes f64 'xmm9 i32 'eax [
	fail "i32 to f64 conversion encoding failed"
]
unless rs-o2-x64/emit-scalar-conversion float-conversion-bytes i32 'r11d f64 'xmm10 [
	fail "f64 to i32 conversion encoding failed"
]
unless rs-o2-x64/emit-scalar-conversion float-conversion-bytes f64 'xmm10 f32 'xmm9 [
	fail "f32 to f64 conversion encoding failed"
]
unless rs-o2-x64/emit-scalar-conversion float-conversion-bytes f32 'xmm9 f64 'xmm10 [
	fail "f64 to f32 conversion encoding failed"
]
unless float-conversion-bytes = #{F2440F2AC8F2450F2CDAF3450F5AD1F2450F5ACA} [
	fail rejoin ["float conversion bytes are wrong: " mold float-conversion-bytes]
]

unless rs-o2-ir/begin-function 'win64-f64-constant 'win64 f64 %machine-ir-smoke.red [
	fail "Win64 f64 constant function did not start"
]
win64-f64-constant: rs-o2-ir/emit-constant -0.0 f64
rs-o2-ir/set-direct-body-range 0 1
win64-f64-selected: rs-o2-ir/finish-function reduce [#{CC} copy []]
unless win64-f64-selected/1 = #{49BB000000000000008066490F6EC3C3} [
	fail rejoin ["Win64 f64 constant selection is wrong: " mold win64-f64-selected/1]
]

unless rs-o2-ir/begin-function 'sysv-f32-constant 'sysv f32 %machine-ir-smoke.red [
	fail "SysV f32 constant function did not start"
]
sysv-f32-constant: rs-o2-ir/emit-constant 1.5 f32
rs-o2-ir/set-direct-body-range 0 1
sysv-f32-selected: rs-o2-ir/finish-function reduce [#{CC} copy []]
unless sysv-f32-selected/1 = #{41BB0000C03F66410F6EC3C3} [
	fail rejoin ["SysV f32 constant selection is wrong: " mold sysv-f32-selected/1]
]

indirect-addressing-bytes: make binary! 64
rs-o2-x64/emit-gpr-pointer-load indirect-addressing-bytes i32 'eax 'ecx 0
rs-o2-x64/emit-gpr-pointer-store indirect-addressing-bytes i64 'r12d 120 'r9d
rs-o2-x64/emit-gpr-pointer-load indirect-addressing-bytes i32 'r10d 'r13d 0
rs-o2-x64/emit-gpr-pointer-load indirect-addressing-bytes ptr-type 'r11d 'r12d 1024
rs-o2-x64/emit-xmm-scalar-pointer-load indirect-addressing-bytes f64 'xmm9 'r13d 8
rs-o2-x64/emit-xmm-scalar-pointer-store indirect-addressing-bytes f32 'r12d -4 'xmm10
unless indirect-addressing-bytes = #{8B014D894C2478458B55004D8B9C2400040000F2450F104D08F3450F115424FC} [
	fail rejoin ["indirect addressing bytes are wrong: " mold indirect-addressing-bytes]
]

aggregate-copy-bytes: make binary! 64
rs-o2-x64/emit-aggregate-slot-load aggregate-copy-bytes 1 'r11d 'eax 0
rs-o2-x64/emit-aggregate-slot-load aggregate-copy-bytes 2 'r11d 'eax 1
rs-o2-x64/emit-aggregate-slot-load aggregate-copy-bytes 4 'r11d 'eax 3
rs-o2-x64/emit-aggregate-slot-load aggregate-copy-bytes 8 'r11d 'eax 7
rs-o2-x64/emit-aggregate-rsp-store aggregate-copy-bytes 1 0 'r11d
rs-o2-x64/emit-aggregate-rsp-store aggregate-copy-bytes 2 1 'r11d
rs-o2-x64/emit-aggregate-rsp-store aggregate-copy-bytes 4 3 'r11d
rs-o2-x64/emit-aggregate-rsp-store aggregate-copy-bytes 8 7 'r11d
rs-o2-x64/emit-gpr-pointer-store aggregate-copy-bytes i8 'eax 0 'esi
rs-o2-x64/emit-gpr-pointer-store aggregate-copy-bytes i16 'r12d 2 'r9d
unless aggregate-copy-bytes = #{440FB618440FB75801448B58034C8B580744881C246644895C240144895C24034C895C24074088306645894C2402} [
	fail rejoin ["aggregate copy bytes are wrong: " mold aggregate-copy-bytes]
]

aggregate-composite-slot-bytes: make binary! 64
rs-o2-x64/emit-aggregate-slot-load aggregate-composite-slot-bytes 3 'eax 'ecx 0
rs-o2-x64/emit-aggregate-slot-load aggregate-composite-slot-bytes 7 'eax 'ecx 0
unless aggregate-composite-slot-bytes = #{440FB759010FB70149C1E3084C09D8448B59038B0149C1E3184C09D8} [
	fail rejoin ["aggregate composite slot bytes are wrong: " mold aggregate-composite-slot-bytes]
]

unless rs-o2-ir/begin-function 'win64-indirect-store 'win64 i32 %machine-ir-smoke.red [
	fail "Win64 indirect store function did not start"
]
rs-o2-ir/add-stack-object 'address 'argument byte-ptr-type 8 8 'pointer
rs-o2-ir/add-stack-object 'value 'argument i32 4 4 'none
win64-indirect-address: rs-o2-ir/emit-load-local 'address byte-ptr-type
win64-indirect-value: rs-o2-ir/emit-load-local 'value i32
rs-o2-ir/emit-store-indirect win64-indirect-address 8 win64-indirect-value i32
win64-indirect-return: rs-o2-ir/emit-load-local 'value i32
rs-o2-ir/set-direct-body-range 0 1
win64-indirect-store-selected: rs-o2-ir/finish-function reduce [#{CC} copy []]
unless win64-indirect-store-selected/1 = #{89510889D0C3} [
	fail rejoin ["Win64 indirect store bytes are wrong: " mold win64-indirect-store-selected/1]
]

unless rs-o2-ir/begin-function 'sysv-indirect-load 'sysv i32 %machine-ir-smoke.red [
	fail "SysV indirect load function did not start"
]
rs-o2-ir/add-stack-object 'address 'argument byte-ptr-type 8 8 'pointer
sysv-indirect-address: rs-o2-ir/emit-load-local 'address byte-ptr-type
sysv-indirect-result: rs-o2-ir/emit-load-indirect sysv-indirect-address 8 i32
rs-o2-ir/set-direct-body-range 0 1
sysv-indirect-load-selected: rs-o2-ir/finish-function reduce [#{CC} copy []]
unless sysv-indirect-load-selected/1 = #{8B4708C3} [
	fail rejoin ["SysV indirect load bytes are wrong: " mold sysv-indirect-load-selected/1]
]

unless rs-o2-ir/begin-function 'win64-indirect-float-store 'win64 f64 %machine-ir-smoke.red [
	fail "Win64 indirect float store function did not start"
]
rs-o2-ir/add-stack-object 'address 'argument byte-ptr-type 8 8 'pointer
rs-o2-ir/add-stack-object 'value 'argument f64 8 8 'none
win64-indirect-float-address: rs-o2-ir/emit-load-local 'address byte-ptr-type
win64-indirect-float-value: rs-o2-ir/emit-load-local 'value f64
rs-o2-ir/emit-store-indirect win64-indirect-float-address 8 win64-indirect-float-value f64
rs-o2-ir/set-direct-body-range 0 1
win64-indirect-float-selected: rs-o2-ir/finish-function reduce [#{CC} copy []]
unless win64-indirect-float-selected/1 = #{F20F114908F20F10C1C3} [
	fail rejoin ["Win64 indirect float store bytes are wrong: " mold win64-indirect-float-selected/1]
]

unless rs-o2-ir/begin-function 'win64-indirect-address 'win64 cell-ptr-type %machine-ir-smoke.red [
	fail "Win64 indirect address function did not start"
]
rs-o2-ir/add-stack-object 'address 'argument byte-ptr-type 8 8 'pointer
win64-address-base: rs-o2-ir/emit-load-local 'address byte-ptr-type
win64-address-result: rs-o2-ir/emit-address-indirect win64-address-base 12 cell-ptr-type
rs-o2-ir/set-direct-body-range 0 1
win64-indirect-address-selected: rs-o2-ir/finish-function reduce [#{CC} copy []]
unless win64-indirect-address-selected/1 = #{488D410CC3} [
	fail rejoin ["Win64 indirect address bytes are wrong: " mold win64-indirect-address-selected/1]
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
unless (pick rs-o2-ir/stats rs-o2-ir/stats-functions) = 7 [fail "function count"]
unless (pick rs-o2-ir/stats rs-o2-ir/stats-verified) = 7 [fail "verification count"]
unless (pick rs-o2-ir/stats rs-o2-ir/stats-eligible) = 7 [fail "eligibility count"]
unless (pick rs-o2-ir/stats rs-o2-ir/stats-selected) = 7 [fail "selection count"]
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
rs-o2-ir/add-stack-object 'value 'argument ptr-type 8 8 'pointer
win-pointer-value: rs-o2-ir/emit-load-local 'value ptr-type
rs-o2-ir/set-direct-body-range 0 1
win-pointer-selected: rs-o2-ir/finish-function reduce [#{90} copy []]
unless win-pointer-selected/1 = #{4889C8C3} [
	fail rejoin ["Win64 pointer identity bytes are wrong: " mold win-pointer-selected/1]
]

unless rs-o2-ir/begin-function 'win64-pointer-greater 'win64 logic-type %machine-ir-smoke.red [
	fail "Win64 pointer greater function did not start"
]
rs-o2-ir/add-stack-object 'left 'argument ptr-type 8 8 'pointer
rs-o2-ir/add-stack-object 'right 'argument ptr-type 8 8 'pointer
win-pointer-greater-left: rs-o2-ir/emit-load-local 'left ptr-type
win-pointer-greater-right: rs-o2-ir/emit-load-local 'right ptr-type
win-pointer-greater-result: rs-o2-ir/emit-binary
	rs-o2-ir/greater-op
	win-pointer-greater-left
	win-pointer-greater-right
	logic-type
	'pure
rs-o2-ir/set-direct-body-range 0 1
win-pointer-greater-selected: rs-o2-ir/finish-function reduce [#{90} copy []]
unless win-pointer-greater-selected/1 = #{4839D10F97C00FB6C0C3} [
	fail rejoin ["Win64 pointer greater bytes are wrong: " mold win-pointer-greater-selected/1]
]

unless rs-o2-ir/begin-function 'sysv-pointer-less 'sysv logic-type %machine-ir-smoke.red [
	fail "SysV pointer less function did not start"
]
rs-o2-ir/add-stack-object 'left 'argument ptr-type 8 8 'pointer
rs-o2-ir/add-stack-object 'right 'argument ptr-type 8 8 'pointer
sysv-pointer-less-left: rs-o2-ir/emit-load-local 'left ptr-type
sysv-pointer-less-right: rs-o2-ir/emit-load-local 'right ptr-type
sysv-pointer-less-result: rs-o2-ir/emit-binary
	rs-o2-ir/less-op
	sysv-pointer-less-left
	sysv-pointer-less-right
	logic-type
	'pure
rs-o2-ir/set-direct-body-range 0 1
sysv-pointer-less-selected: rs-o2-ir/finish-function reduce [#{90} copy []]
unless sysv-pointer-less-selected/1 = #{4839F70F92C00FB6C0C3} [
	fail rejoin ["SysV pointer less bytes are wrong: " mold sysv-pointer-less-selected/1]
]

unless rs-o2-ir/begin-function 'win64-pointer-add-scaled 'win64 ptr-type %machine-ir-smoke.red [
	fail "Win64 scaled pointer addition function did not start"
]
rs-o2-ir/add-stack-object 'base 'argument ptr-type 8 8 'pointer
rs-o2-ir/add-stack-object 'index 'argument i32 4 4 'none
win-pointer-add-base: rs-o2-ir/emit-load-local 'base ptr-type
win-pointer-add-index: rs-o2-ir/emit-load-local 'index i32
win-pointer-add-result: rs-o2-ir/emit-binary
	rs-o2-ir/add-op
	win-pointer-add-base
	win-pointer-add-index
	ptr-type
	'pure
rs-o2-ir/set-direct-body-range 0 1
win-pointer-add-selected: rs-o2-ir/finish-function reduce [#{90} copy []]
unless win-pointer-add-selected/1 = #{4C63DA4A8D0499C3} [
	fail rejoin ["Win64 scaled pointer addition bytes are wrong: " mold win-pointer-add-selected/1]
]

unless rs-o2-ir/begin-function 'win64-pointer-add-folded-frame 'win64 ptr-type %machine-ir-smoke.red [
	fail "Win64 folded frame pointer addition function did not start"
]
rs-o2-ir/add-stack-object 'base 'argument ptr-type 8 8 'pointer
rs-o2-ir/add-stack-object 'index 'argument i32 4 4 'none
rs-o2-ir/add-stack-object 'frame-marker 'local i32 4 4 'none
rs-o2-ir/set-stack-offset 'base -40
rs-o2-ir/set-stack-offset 'index -48
rs-o2-ir/set-stack-offset 'frame-marker -56
rs-o2-ir/mark-stack-object-escaped 'frame-marker
win-pointer-folded-base: rs-o2-ir/emit-load-local 'base ptr-type
win-pointer-folded-index: rs-o2-ir/emit-load-local 'index i32
win-pointer-folded-result: rs-o2-ir/emit-binary
	rs-o2-ir/add-op
	win-pointer-folded-base
	win-pointer-folded-index
	ptr-type
	'pure
rs-o2-ir/set-direct-body-range 0 1
win-pointer-folded-selected: rs-o2-ir/finish-function reduce [#{CC} copy []]
unless find win-pointer-folded-selected/1 #{4C635DD0} [
	fail rejoin ["Win64 folded frame pointer addition bytes are wrong: " mold win-pointer-folded-selected/1]
]

unless rs-o2-ir/begin-function 'sysv-pointer-add-scaled 'sysv ptr-type %machine-ir-smoke.red [
	fail "SysV scaled pointer addition function did not start"
]
rs-o2-ir/add-stack-object 'base 'argument ptr-type 8 8 'pointer
rs-o2-ir/add-stack-object 'index 'argument i32 4 4 'none
sysv-pointer-add-base: rs-o2-ir/emit-load-local 'base ptr-type
sysv-pointer-add-index: rs-o2-ir/emit-load-local 'index i32
sysv-pointer-add-result: rs-o2-ir/emit-binary
	rs-o2-ir/add-op
	sysv-pointer-add-base
	sysv-pointer-add-index
	ptr-type
	'pure
rs-o2-ir/set-direct-body-range 0 1
sysv-pointer-add-selected: rs-o2-ir/finish-function reduce [#{90} copy []]
unless sysv-pointer-add-selected/1 = #{4C63DE4A8D049FC3} [
	fail rejoin ["SysV scaled pointer addition bytes are wrong: " mold sysv-pointer-add-selected/1]
]

unless rs-o2-ir/begin-function 'win64-pointer-add-immediate 'win64 ptr-type %machine-ir-smoke.red [
	fail "Win64 immediate pointer addition function did not start"
]
rs-o2-ir/add-stack-object 'base 'argument ptr-type 8 8 'pointer
win-pointer-immediate-base: rs-o2-ir/emit-load-local 'base ptr-type
win-pointer-immediate-index: rs-o2-ir/emit-constant 2 i32
win-pointer-immediate-result: rs-o2-ir/emit-binary
	rs-o2-ir/add-op
	win-pointer-immediate-base
	win-pointer-immediate-index
	ptr-type
	'pure
rs-o2-ir/set-direct-body-range 0 1
win-pointer-immediate-selected: rs-o2-ir/finish-function reduce [#{90} copy []]
unless win-pointer-immediate-selected/1 = #{488D4108C3} [
	fail rejoin ["Win64 immediate pointer addition bytes are wrong: " mold win-pointer-immediate-selected/1]
]

unless rs-o2-ir/begin-function 'win64-cell-pointer-add 'win64 cell-ptr-type %machine-ir-smoke.red [
	fail "Win64 cell pointer addition function did not start"
]
rs-o2-ir/add-stack-object 'base 'argument cell-ptr-type 8 8 'pointer
rs-o2-ir/add-stack-object 'index 'argument i32 4 4 'none
win-cell-add-base: rs-o2-ir/emit-load-local 'base cell-ptr-type
win-cell-add-index: rs-o2-ir/emit-load-local 'index i32
win-cell-add-result: rs-o2-ir/emit-binary
	rs-o2-ir/add-op
	win-cell-add-base
	win-cell-add-index
	cell-ptr-type
	'pure
rs-o2-ir/set-direct-body-range 0 1
win-cell-add-selected: rs-o2-ir/finish-function reduce [#{90} copy []]
unless win-cell-add-selected/1 = #{4C63DA49C1E3044A8D0419C3} [
	fail rejoin ["Win64 cell pointer addition bytes are wrong: " mold win-cell-add-selected/1]
]

unless rs-o2-ir/begin-function 'win64-pointer-subtract-scaled 'win64 ptr-type %machine-ir-smoke.red [
	fail "Win64 scaled pointer subtraction function did not start"
]
rs-o2-ir/add-stack-object 'base 'argument ptr-type 8 8 'pointer
rs-o2-ir/add-stack-object 'index 'argument i32 4 4 'none
win-pointer-sub-base: rs-o2-ir/emit-load-local 'base ptr-type
win-pointer-sub-index: rs-o2-ir/emit-load-local 'index i32
win-pointer-sub-result: rs-o2-ir/emit-binary
	rs-o2-ir/subtract-op
	win-pointer-sub-base
	win-pointer-sub-index
	ptr-type
	'pure
rs-o2-ir/set-direct-body-range 0 1
win-pointer-sub-selected: rs-o2-ir/finish-function reduce [#{90} copy []]
unless win-pointer-sub-selected/1 = #{4C63DA49C1E3024889C84C29D8C3} [
	fail rejoin ["Win64 scaled pointer subtraction bytes are wrong: " mold win-pointer-sub-selected/1]
]

unless rs-o2-ir/begin-function 'pointer-immediate-overflow 'win64 ptr-type %machine-ir-smoke.red [
	fail "pointer immediate overflow function did not start"
]
rs-o2-ir/add-stack-object 'base 'argument ptr-type 8 8 'pointer
pointer-overflow-base: rs-o2-ir/emit-load-local 'base ptr-type
pointer-overflow-index: rs-o2-ir/emit-constant 1073741824 i32
pointer-overflow-result: rs-o2-ir/emit-binary
	rs-o2-ir/add-op
	pointer-overflow-base
	pointer-overflow-index
	ptr-type
	'pure
rs-o2-ir/set-direct-body-range 0 1
pointer-overflow-selected: rs-o2-ir/finish-function reduce [#{CC} copy []]
unless pointer-overflow-selected/1 = #{CC} [
	fail "overflowing scaled pointer immediate did not fall back"
]

unless rs-o2-ir/begin-function 'win64-copy-cell 'win64 ptr-type %machine-ir-smoke.red [
	fail "Win64 copy-cell function did not start"
]
rs-o2-ir/add-stack-object 'source 'argument ptr-type 8 8 'pointer
rs-o2-ir/add-stack-object 'destination 'argument ptr-type 8 8 'pointer
win-copy-source: rs-o2-ir/emit-load-local 'source ptr-type
win-copy-destination: rs-o2-ir/emit-load-local 'destination ptr-type
win-copy-result: rs-o2-ir/emit-copy-cell win-copy-source win-copy-destination ptr-type
rs-o2-ir/set-direct-body-range 0 1
win-copy-selected: rs-o2-ir/finish-function reduce [#{90} copy []]
unless win-copy-selected/1 = #{0F10290F112A4889D0C3} [
	fail rejoin ["Win64 copy-cell bytes are wrong: " mold win-copy-selected/1]
]

unless rs-o2-ir/begin-function 'sysv-copy-cell 'sysv ptr-type %machine-ir-smoke.red [
	fail "SysV copy-cell function did not start"
]
rs-o2-ir/add-stack-object 'source 'argument ptr-type 8 8 'pointer
rs-o2-ir/add-stack-object 'destination 'argument ptr-type 8 8 'pointer
sysv-copy-source: rs-o2-ir/emit-load-local 'source ptr-type
sysv-copy-destination: rs-o2-ir/emit-load-local 'destination ptr-type
sysv-copy-result: rs-o2-ir/emit-copy-cell sysv-copy-source sysv-copy-destination ptr-type
rs-o2-ir/set-direct-body-range 0 1
sysv-copy-selected: rs-o2-ir/finish-function reduce [#{90} copy []]
unless sysv-copy-selected/1 = #{440F103F440F113E4889F0C3} [
	fail rejoin ["SysV copy-cell bytes are wrong: " mold sysv-copy-selected/1]
]

unless rs-o2-ir/begin-function 'win64-resolve-node 'win64 ptr-type %machine-ir-smoke.red [
	fail "Win64 resolve-node function did not start"
]
rs-o2-ir/add-stack-object 'handle 'argument i32 4 4 'none
win-resolve-handle: rs-o2-ir/emit-load-local 'handle i32
win-resolve-result: rs-o2-ir/emit-resolver 'red>resolve-node win-resolve-handle ptr-type
rs-o2-ir/set-direct-body-range 0 5
win-node-registry-relocs: reduce [1501]
put emitter/symbols 'red>node-registry reduce ['global none win-node-registry-relocs]
win-resolve-selected: rs-o2-ir/finish-function reduce [
	#{0000000000} reduce [win-node-registry-relocs] 1500
]
unless all [
	find win-resolve-selected/1 #{85C90F84}
	find win-resolve-selected/1 #{3B4814}
	find win-resolve-selected/1 #{4863C9488B44C8F8}
	find win-resolve-selected/1 #{31C0}
	none? find win-resolve-selected/1 #{E800000000}
][fail rejoin ["Win64 resolve-node bytes are wrong: " mold win-resolve-selected/1]]
unless win-node-registry-relocs/1 > 1501 [fail "Win64 resolve-node relocation was not moved"]

unless rs-o2-ir/begin-function 'win64-resolve-series 'win64 ptr-type %machine-ir-smoke.red [
	fail "Win64 resolve-series function did not start"
]
rs-o2-ir/add-stack-object 'handle 'argument i32 4 4 'none
rs-o2-ir/set-stack-offset 'handle -8
win-series-handle: rs-o2-ir/emit-load-local 'handle i32
win-series-result: rs-o2-ir/emit-resolver 'red>resolve-series win-series-handle ptr-type
rs-o2-ir/set-direct-body-range 0 10
win-series-registry-relocs: reduce [1601]
win-series-call-relocs: reduce [1606]
put emitter/symbols 'red>node-registry reduce ['global none win-series-registry-relocs]
put emitter/symbols 'red>resolve-series reduce ['native none win-series-call-relocs]
win-series-selected: rs-o2-ir/finish-function reduce [
	#{00000000000000000000}
	reduce [win-series-registry-relocs win-series-call-relocs]
	1600
]
unless all [
	find win-series-selected/1 #{85C90F84}
	find win-series-selected/1 #{3B4814}
	find win-series-selected/1 #{4863C9488B44C8F8}
	find win-series-selected/1 #{4885C0}
	find win-series-selected/1 #{E800000000}
][fail rejoin ["Win64 resolve-series bytes are wrong: " mold win-series-selected/1]]
unless all [
	win-series-registry-relocs/1 > 1601
	win-series-call-relocs/1 > win-series-registry-relocs/1
][fail "Win64 resolve-series relocations were not moved in order"]

unless rs-o2-ir/begin-function 'sysv-resolve-series 'sysv ptr-type %machine-ir-smoke.red [
	fail "SysV resolve-series function did not start"
]
rs-o2-ir/add-stack-object 'handle 'argument i32 4 4 'none
rs-o2-ir/set-stack-offset 'handle -8
sysv-series-handle: rs-o2-ir/emit-load-local 'handle i32
sysv-series-result: rs-o2-ir/emit-resolver 'red>resolve-series sysv-series-handle ptr-type
rs-o2-ir/set-direct-body-range 0 10
sysv-series-registry-relocs: reduce [1701]
sysv-series-call-relocs: reduce [1706]
put emitter/symbols 'red>node-registry reduce ['global none sysv-series-registry-relocs]
put emitter/symbols 'red>resolve-series reduce ['native none sysv-series-call-relocs]
sysv-series-selected: rs-o2-ir/finish-function reduce [
	#{00000000000000000000}
	reduce [sysv-series-registry-relocs sysv-series-call-relocs]
	1700
]
unless all [
	find sysv-series-selected/1 #{85FF0F84}
	find sysv-series-selected/1 #{3B7814}
	find sysv-series-selected/1 #{4863FF488B44F8F8}
	find sysv-series-selected/1 #{E800000000}
][fail rejoin ["SysV resolve-series bytes are wrong: " mold sysv-series-selected/1]]

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
rs-o2-x64/emit-materialized-condition sysv-logic-bytes rs-o2-ir/less-op i32 'edi
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

unless rs-o2-ir/begin-function 'win64-f64-equal 'win64 logic-type %machine-ir-smoke.red [
	fail "Win64 f64 equality function did not start"
]
rs-o2-ir/add-stack-object 'a 'argument f64 8 8 'none
rs-o2-ir/add-stack-object 'b 'argument f64 8 8 'none
f64-equal-a: rs-o2-ir/emit-load-local 'a f64
f64-equal-b: rs-o2-ir/emit-load-local 'b f64
f64-equal-result: rs-o2-ir/emit-binary
	rs-o2-ir/equal-op f64-equal-a f64-equal-b logic-type 'pure
rs-o2-ir/set-direct-body-range 0 1
f64-equal-selected: rs-o2-ir/finish-function reduce [#{90} copy []]
unless f64-equal-selected/1 = #{660F2EC10F94C00FB6C07B05B800000000C3} [
	fail rejoin ["Win64 f64 equality bytes are wrong: " mold f64-equal-selected/1]
]

unless rs-o2-ir/begin-function 'win64-f64-equal-integer 'win64 i32 %machine-ir-smoke.red [
	fail "Win64 f64 integer equality function did not start"
]
rs-o2-ir/add-stack-object 'a 'argument f64 8 8 'none
rs-o2-ir/add-stack-object 'b 'argument f64 8 8 'none
f64-equal-integer-a: rs-o2-ir/emit-load-local 'a f64
f64-equal-integer-b: rs-o2-ir/emit-load-local 'b f64
f64-equal-logic: rs-o2-ir/emit-binary
	rs-o2-ir/equal-op f64-equal-integer-a f64-equal-integer-b logic-type 'pure
f64-equal-integer-result: rs-o2-ir/emit-bitcast f64-equal-logic i32
rs-o2-ir/set-direct-body-range 0 1
f64-equal-integer-selected: rs-o2-ir/finish-function reduce [#{90} copy []]
unless f64-equal-integer-selected/1 = #{660F2EC10F94C00FB6C07B05B800000000C3} [
	fail rejoin [
		"Win64 f64 integer equality bytes are wrong: "
		mold f64-equal-integer-selected/1
	]
]

unless rs-o2-ir/begin-function 'win64-f32-not-equal 'win64 logic-type %machine-ir-smoke.red [
	fail "Win64 f32 inequality function did not start"
]
rs-o2-ir/add-stack-object 'a 'argument f32 4 4 'none
rs-o2-ir/add-stack-object 'b 'argument f32 4 4 'none
f32-not-equal-a: rs-o2-ir/emit-load-local 'a f32
f32-not-equal-b: rs-o2-ir/emit-load-local 'b f32
f32-not-equal-result: rs-o2-ir/emit-binary
	rs-o2-ir/not-equal-op f32-not-equal-a f32-not-equal-b logic-type 'pure
rs-o2-ir/set-direct-body-range 0 1
f32-not-equal-selected: rs-o2-ir/finish-function reduce [#{90} copy []]
unless f32-not-equal-selected/1 = #{0F2EC10F95C00FB6C07B05B801000000C3} [
	fail rejoin ["Win64 f32 inequality bytes are wrong: " mold f32-not-equal-selected/1]
]

unless rs-o2-ir/begin-function 'win64-f64-less-branch 'win64 i32 %machine-ir-smoke.red [
	fail "Win64 f64 branch function did not start"
]
rs-o2-ir/add-stack-object 'a 'argument f64 8 8 'none
rs-o2-ir/add-stack-object 'b 'argument f64 8 8 'none
rs-o2-ir/add-stack-object 'result 'local i32 4 4 'none
rs-o2-ir/set-stack-offset 'a -16
rs-o2-ir/set-stack-offset 'b -24
rs-o2-ir/set-stack-offset 'result -8
f64-branch-zero: rs-o2-ir/emit-constant 0 i32
rs-o2-ir/emit-store-local 'result f64-branch-zero i32
f64-branch-state: rs-o2-ir/begin-if
f64-branch-a: rs-o2-ir/emit-load-local 'a f64
f64-branch-b: rs-o2-ir/emit-load-local 'b f64
f64-branch-test: rs-o2-ir/emit-binary
	rs-o2-ir/less-op f64-branch-a f64-branch-b logic-type 'pure
rs-o2-ir/if-condition f64-branch-state
f64-branch-one: rs-o2-ir/emit-constant 1 i32
rs-o2-ir/emit-store-local 'result f64-branch-one i32
rs-o2-ir/end-if f64-branch-state
f64-branch-result: rs-o2-ir/emit-load-local 'result i32
rs-o2-ir/set-direct-body-range 0 1
f64-branch-selected: rs-o2-ir/finish-function reduce [#{90} copy []]
unless find f64-branch-selected/1 #{660F2E} [fail "f64 branch did not emit UCOMISD"]
unless any [find f64-branch-selected/1 #{7A} find f64-branch-selected/1 #{0F8A}] [
	fail "f64 branch did not guard the unordered case"
]
if find f64-branch-selected/1 #{0F92} [
	fail "branch-only f64 comparison materialized a logic value"
]

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
while-body-block: pick (pick rs-o2-ir/current rs-o2-ir/fn-blocks) while-state/2
while-body-first-instruction: first pick while-body-block rs-o2-ir/bb-instructions
rs-o2-ir/set-direct-body-range 0 1
while-selected: rs-o2-ir/finish-function reduce [#{90} copy []]
unless find while-selected/1 #{0F8C} [fail "while CFG near backward condition was not selected"]
unless find while-selected/1 #{E9} [fail "while CFG stable near jump was not selected"]
unless find while-selected/1 #{448B4DF8} [fail "live-in promoted argument was not loaded"]
if find while-selected/1 #{448B45F0} [fail "definitely assigned local was loaded at entry"]
if find while-selected/1 #{0F9C} [fail "branch-only comparison materialized a logic value"]
while-body-offset: rs-o2-ir/table-value
	rs-o2-x64/encoded-instruction-offsets
	pick while-body-first-instruction rs-o2-ir/ins-id
unless all [integer? while-body-offset zero? (while-body-offset // 32)][
	fail rejoin ["while body was not 32-byte aligned: " mold while-body-offset]
]

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
unless none? (pick rs-o2-ir/current rs-o2-ir/fn-last-result) [
	fail "if CFG retained a true-edge-only result"
]
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

unless rs-o2-ir/begin-function 'sparse-switch-cfg 'win64 i32 %machine-ir-smoke.red [
	fail "sparse switch CFG function did not start"
]
rs-o2-ir/add-stack-object 'switch-selector 'argument i32 4 4 'none
rs-o2-ir/add-stack-object 'switch-source 'argument i32 4 4 'none
rs-o2-ir/set-stack-offset 'switch-selector -8
rs-o2-ir/set-stack-offset 'switch-source -16
sparse-switch-selector: rs-o2-ir/emit-load-local 'switch-selector i32
sparse-switch-values: [-550 -450 -350 -250 -150 -50 50 150 250 350 450 550]
sparse-switch-groups: make block! length? sparse-switch-values
foreach sparse-switch-value sparse-switch-values [
	append/only sparse-switch-groups reduce [sparse-switch-value]
]
sparse-switch-state: rs-o2-ir/begin-switch sparse-switch-groups yes
unless sparse-switch-state [fail "sparse switch CFG was rejected"]
repeat sparse-switch-index length? sparse-switch-values [
	rs-o2-ir/begin-switch-case sparse-switch-state
	sparse-switch-value: rs-o2-ir/emit-load-local 'switch-source i32
	rs-o2-ir/end-switch-case sparse-switch-state
]
rs-o2-ir/begin-switch-default sparse-switch-state
sparse-switch-default: rs-o2-ir/emit-load-local 'switch-source i32
rs-o2-ir/end-switch-default sparse-switch-state
sparse-switch-merged: rs-o2-ir/end-switch sparse-switch-state
unless sparse-switch-merged [fail "sparse switch result was not merged"]
sparse-switch-one: rs-o2-ir/emit-constant 1 i32
sparse-switch-result: rs-o2-ir/emit-binary
	rs-o2-ir/add-op
	sparse-switch-merged
	sparse-switch-one
	i32
	'pure
rs-o2-ir/set-direct-body-range 0 1
sparse-switch-selected: rs-o2-ir/finish-function reduce [#{90} copy []]
if sparse-switch-selected/1 = #{90} [fail "sparse switch retained direct code"]
unless find sparse-switch-selected/1 #{0F8C} [fail "sparse switch tree has no signed left branch"]
unless any [
	find sparse-switch-selected/1 #{74}
	find sparse-switch-selected/1 #{0F84}
][fail "sparse switch tree has no equality branch"]
unless find sparse-switch-selected/1 #{4489C0} [
	fail rejoin ["sparse switch phi edge copy is missing: " mold sparse-switch-selected/1]
]
unless (length? rs-o2-x64/phi-edge-copies) = 26 [
	fail rejoin ["sparse switch phi edge plan is wrong: " mold rs-o2-x64/phi-edge-copies]
]

unless rs-o2-ir/begin-function 'dense-switch-cfg 'win64 i32 %machine-ir-smoke.red [
	fail "dense switch CFG function did not start"
]
rs-o2-ir/add-stack-object 'dense-switch-selector 'argument i32 4 4 'none
rs-o2-ir/set-stack-offset 'dense-switch-selector -8
dense-switch-selector: rs-o2-ir/emit-load-local 'dense-switch-selector i32
dense-switch-groups: make block! 32
repeat dense-switch-index 32 [
	append/only dense-switch-groups reduce [dense-switch-index - 1]
]
dense-switch-state: rs-o2-ir/begin-switch dense-switch-groups yes
unless dense-switch-state [fail "dense switch CFG was rejected"]
repeat dense-switch-index 32 [
	rs-o2-ir/begin-switch-case dense-switch-state
	dense-switch-value: rs-o2-ir/emit-constant dense-switch-index i32
	rs-o2-ir/end-switch-case dense-switch-state
]
rs-o2-ir/begin-switch-default dense-switch-state
dense-switch-default: rs-o2-ir/emit-constant 99 i32
rs-o2-ir/end-switch-default dense-switch-state
dense-switch-result: rs-o2-ir/end-switch dense-switch-state
rs-o2-ir/set-direct-body-range 0 1
dense-switch-direct: reduce [#{CC} copy []]
dense-switch-selected: rs-o2-ir/finish-function dense-switch-direct
if dense-switch-selected/1 = #{CC} [fail "dense switch retained direct code"]
unless find dense-switch-selected/1 #{4C8D1D09000000496304834C01D8FFE0} [
	fail rejoin ["dense switch jump-table dispatch is missing: " mold dense-switch-selected/1]
]
unless find dense-switch-selected/1 #{31C0FFC0} [
	fail "dense switch constant-one layout is missing"
]
unless (length? rs-o2-x64/jump-table-patches) = 32 [
	fail rejoin ["dense switch table patch plan is wrong: " mold rs-o2-x64/jump-table-patches]
]

unless rs-o2-ir/begin-function 'small-dense-switch-cfg 'win64 i32 %machine-ir-smoke.red [
	fail "small dense switch CFG function did not start"
]
rs-o2-ir/add-stack-object 'small-dense-selector 'argument i32 4 4 'none
rs-o2-ir/set-stack-offset 'small-dense-selector -8
small-dense-selector: rs-o2-ir/emit-load-local 'small-dense-selector i32
small-dense-groups: make block! 5
repeat small-dense-index 5 [
	append/only small-dense-groups reduce [small-dense-index + 1]
]
small-dense-state: rs-o2-ir/begin-switch small-dense-groups yes
unless small-dense-state [fail "small dense switch CFG was rejected"]
repeat small-dense-index 5 [
	rs-o2-ir/begin-switch-case small-dense-state
	small-dense-value: rs-o2-ir/emit-constant small-dense-index * 4 i32
	rs-o2-ir/end-switch-case small-dense-state
]
rs-o2-ir/begin-switch-default small-dense-state
small-dense-default: rs-o2-ir/emit-constant 0 i32
rs-o2-ir/end-switch-default small-dense-state
small-dense-result: rs-o2-ir/end-switch small-dense-state
small-dense-direct: reduce [#{CC} copy []]
small-dense-selected: rs-o2-ir/finish-function small-dense-direct
if small-dense-selected/1 = #{CC} [fail "small dense switch retained direct code"]
unless (copy/part small-dense-selected/1 12) = #{89C82D020000003D04000000} [
	fail rejoin ["small dense switch was not emitted frameless: " mold small-dense-selected/1]
]
unless (last small-dense-selected/1) = 195 [fail "small dense switch has no return"]
unless find small-dense-selected/1 #{2D020000003D04000000} [
	fail rejoin ["small dense switch range check is missing: " mold small-dense-selected/1]
]
unless find small-dense-selected/1 #{4C8D1D09000000496304834C01D8FFE0} [
	fail "small dense switch jump-table dispatch is missing"
]
unless (length? rs-o2-x64/jump-table-patches) = 5 [
	fail rejoin ["small dense switch table patch plan is wrong: " mold rs-o2-x64/jump-table-patches]
]

unless rs-o2-ir/begin-function 'small-dense-switch-sysv 'sysv i32 %machine-ir-smoke.red [
	fail "SysV small dense switch function did not start"
]
rs-o2-ir/add-stack-object 'sysv-small-dense-selector 'argument i32 4 4 'none
rs-o2-ir/set-stack-offset 'sysv-small-dense-selector -8
sysv-small-dense-selector: rs-o2-ir/emit-load-local 'sysv-small-dense-selector i32
sysv-small-dense-state: rs-o2-ir/begin-switch small-dense-groups yes
unless sysv-small-dense-state [fail "SysV small dense switch CFG was rejected"]
repeat small-dense-index 5 [
	rs-o2-ir/begin-switch-case sysv-small-dense-state
	sysv-small-dense-value: rs-o2-ir/emit-constant small-dense-index * 4 i32
	rs-o2-ir/end-switch-case sysv-small-dense-state
]
rs-o2-ir/begin-switch-default sysv-small-dense-state
sysv-small-dense-default: rs-o2-ir/emit-constant 0 i32
rs-o2-ir/end-switch-default sysv-small-dense-state
sysv-small-dense-result: rs-o2-ir/end-switch sysv-small-dense-state
sysv-small-dense-selected: rs-o2-ir/finish-function reduce [#{CC} copy []]
unless (copy/part sysv-small-dense-selected/1 12) = #{89F82D020000003D04000000} [
	fail rejoin ["SysV small dense switch was not emitted frameless: " mold sysv-small-dense-selected/1]
]
unless (last sysv-small-dense-selected/1) = 195 [
	fail "SysV small dense switch has no return"
]

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

unless rs-o2-ir/begin-function 'immediate-left-memory 'win64 i32 %machine-ir-smoke.red [
	fail "immediate plus memory function did not start"
]
foreach [name offset] [a -8 b -16 c -24 d -32 e -40][
	rs-o2-ir/add-stack-object name 'argument i32 4 4 'none
	rs-o2-ir/set-stack-offset name offset
]
immediate-left-value: rs-o2-ir/emit-constant 118 i32
immediate-left-memory: rs-o2-ir/emit-load-local 'e i32
immediate-left-result: rs-o2-ir/emit-binary
	rs-o2-ir/add-op immediate-left-value immediate-left-memory i32 'pure
rs-o2-ir/set-direct-body-range 0 1
immediate-left-selected: rs-o2-ir/finish-function reduce [#{90} copy []]
unless find immediate-left-selected/1 #{B8760000000345D8} [
	fail rejoin [
		"immediate plus frame-memory used an uninitialized register: "
		mold immediate-left-selected/1
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

unless rs-o2-ir/begin-function 'win64-variadic-import 'win64 i32 %machine-ir-smoke.red [
	fail "Win64 variadic import function did not start"
]
rs-o2-ir/add-stack-object 'tag 'argument i32 4 4 'none
rs-o2-ir/add-stack-object 'value 'argument f64 8 8 'none
rs-o2-ir/set-stack-offset 'tag -8
rs-o2-ir/set-stack-offset 'value -16
win64-variadic-tag: rs-o2-ir/emit-load-local 'tag i32
win64-variadic-value: rs-o2-ir/emit-load-local 'value f64
win64-variadic-result: rs-o2-ir/emit-call/variadic
	'win64-variadic-callee
	reduce [win64-variadic-tag win64-variadic-value]
	i32
rs-o2-ir/set-direct-body-range 0 6
win64-variadic-relocs: reduce [2102]
put emitter/symbols 'win64-variadic-callee reduce ['import none win64-variadic-relocs]
win64-variadic-selected: rs-o2-ir/finish-function reduce [
	#{FF1500000000} reduce [win64-variadic-relocs] 2100
]
unless all [
	find win64-variadic-selected/1 #{4883EC20}
	find win64-variadic-selected/1 #{66480F7ECA}
	find win64-variadic-selected/1 #{FF1500000000}
][fail rejoin ["Win64 variadic import bytes are wrong: " mold win64-variadic-selected/1]]
unless all [
	rs-o2-x64/outgoing-frame-bytes = 32
	rs-o2-x64/spill-frame-bytes = 32
][fail "Win64 variadic import shadow area is wrong"]
unless win64-variadic-relocs/1 > 2102 [fail "Win64 variadic import relocation was not moved"]

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
unless find promoted-call-selected/1 #{89D9} [
	fail rejoin ["promoted call argument move was not selected: " mold promoted-call-selected/1]
]
if any [
	find promoted-call-selected/1 #{448945F0}
	find promoted-call-selected/1 #{448B45F0}
][fail "callee-saved promoted local was flushed around the call"]
unless all [
	find promoted-call-selected/1 #{48895DD8}
	find promoted-call-selected/1 #{488B5DD8}
][fail "promoted EBX was not saved and restored once"]
unless promoted-callee-relocs/1 > 301 [fail "promoted call relocation was not moved"]

unless rs-o2-ir/begin-function 'promoted-third-argument 'win64 i32 %machine-ir-smoke.red [
	fail "promoted third-argument function did not start"
]
rs-o2-ir/add-stack-object 'promoted-size 'argument i32 4 4 'none
rs-o2-ir/set-stack-offset 'promoted-size -8
promoted-size-value: rs-o2-ir/emit-load-local 'promoted-size i32
promoted-size-zero: rs-o2-ir/emit-constant 0 i32
promoted-size-test: rs-o2-ir/emit-binary
	rs-o2-ir/equal-op
	promoted-size-value
	promoted-size-zero
	logic-type
	'pure
promoted-size-if: rs-o2-ir/begin-if
rs-o2-ir/if-condition promoted-size-if
promoted-size-sixteen: rs-o2-ir/emit-constant 16 i32
rs-o2-ir/emit-store-local 'promoted-size promoted-size-sixteen i32
rs-o2-ir/end-if promoted-size-if
promoted-call-size: rs-o2-ir/emit-load-local 'promoted-size i32
promoted-call-unit: rs-o2-ir/emit-constant 1 i32
promoted-call-flags: rs-o2-ir/emit-constant 0 i32
promoted-third-result: rs-o2-ir/emit-call
	'promoted-third-callee
	reduce [promoted-call-size promoted-call-unit promoted-call-flags]
	i32
rs-o2-ir/set-direct-body-range 0 5
promoted-third-relocs: reduce [351]
put emitter/symbols 'promoted-third-callee reduce ['native none promoted-third-relocs]
promoted-third-selected: rs-o2-ir/finish-function reduce [
	#{E800000000} reduce [promoted-third-relocs] 350
]
unless find promoted-third-selected/1 #{89D9} [
	fail rejoin [
		"promoted EBX value was not copied to the first call argument: "
		mold promoted-third-selected/1
	]
]
unless promoted-third-relocs/1 > 351 [fail "promoted third-argument relocation was not moved"]

unless rs-o2-ir/begin-function 'short-circuit-any 'win64 logic-type %machine-ir-smoke.red [
	fail "short-circuit function did not start"
]
rs-o2-ir/add-stack-object 'short-value 'argument i32 4 4 'none
rs-o2-ir/set-stack-offset 'short-value -8
short-state: rs-o2-ir/begin-short-circuit no
short-value-a: rs-o2-ir/emit-load-local 'short-value i32
short-fifteen: rs-o2-ir/emit-constant 15 i32
short-test-a: rs-o2-ir/emit-binary
	rs-o2-ir/equal-op
	short-value-a
	short-fifteen
	logic-type
	'pure
rs-o2-ir/short-circuit-condition short-state no
short-value-b: rs-o2-ir/emit-load-local 'short-value i32
short-twenty: rs-o2-ir/emit-constant 20 i32
short-test-b: rs-o2-ir/emit-binary
	rs-o2-ir/equal-op
	short-value-b
	short-twenty
	logic-type
	'pure
rs-o2-ir/short-circuit-condition short-state yes
short-result: rs-o2-ir/end-short-circuit short-state
rs-o2-ir/set-direct-body-range 0 1
short-selected: rs-o2-ir/finish-function reduce [#{90} copy []]
unless all [
	short-selected/1 <> #{90}
	find short-selected/1 #{4183F80F}
	find short-selected/1 #{4183F814}
][fail rejoin ["short-circuit bytes are wrong: " mold short-selected/1]]

unless rs-o2-ir/begin-function 'short-circuit-call 'win64 logic-type %machine-ir-smoke.red [
	fail "short-circuit call function did not start"
]
short-call-state: rs-o2-ir/begin-short-circuit no
short-call-result: rs-o2-ir/emit-call 'short-circuit-callee copy [] logic-type
rs-o2-ir/short-circuit-condition short-call-state yes
short-call-result: rs-o2-ir/end-short-circuit short-call-state
rs-o2-ir/set-direct-body-range 0 5
short-call-relocs: reduce [1901]
put emitter/symbols 'short-circuit-callee reduce ['native none short-call-relocs]
short-call-selected: rs-o2-ir/finish-function reduce [
	#{E800000000} reduce [short-call-relocs] 1900
]
unless all [
	short-call-selected/1 <> #{E800000000}
	find short-call-selected/1 #{85C0}
	find short-call-selected/1 #{E800000000}
][fail rejoin ["materialized short-circuit bytes are wrong: " mold short-call-selected/1]]

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
unless sysv-call-selected/1 = #{4883E4F08B7DF88B75F0E800000000} [
	fail "SysV direct call bytes are wrong"
]
unless sysv-callee-relocs/1 = 211 [fail "SysV direct call relocation was not moved"]

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
unless sysv-mixed-selected/1 = #{4883E4F08B7DF8F20F1045F0E800000000} [
	fail "SysV mixed direct call bytes are wrong"
]
unless sysv-mixed-relocs/1 = 513 [fail "SysV mixed call relocation was not moved"]

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
unless find win64-five-selected/1 #{4889442420} [
	fail rejoin ["Win64 fifth integer argument was not stored to its full stack slot: " mold win64-five-selected/1]
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
unless find sysv-seven-selected/1 #{48890424} [
	fail rejoin ["SysV seventh integer argument was not stored to its full stack slot: " mold sysv-seven-selected/1]
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
sysv-nine-float-result: rs-o2-ir/emit-call/variadic
	'sysv-nine-float-callee
	sysv-nine-float-values
	f64
rs-o2-ir/set-direct-body-range 0 5
sysv-nine-float-relocs: reduce [1001]
put emitter/symbols 'sysv-nine-float-callee reduce ['import none sysv-nine-float-relocs]
sysv-nine-float-selected: rs-o2-ir/finish-function reduce [
	#{E800000000} reduce [sysv-nine-float-relocs] 1000
]
unless find sysv-nine-float-selected/1 #{4883EC10} [
	fail "SysV nine-float outgoing call area was not reserved once"
]
unless find sysv-nine-float-selected/1 #{F2440F110424} [
	fail rejoin ["SysV ninth float argument did not use XMM8: " mold sysv-nine-float-selected/1]
]
unless find sysv-nine-float-selected/1 #{B008E800000000} [
	fail rejoin ["SysV variadic XMM count was not emitted: " mold sysv-nine-float-selected/1]
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
live-call-relocs: reduce [1120]
put emitter/symbols 'live-call-callee reduce ['native none live-call-relocs]
live-call-direct-bytes: copy #{554889E56A006A0068000000006A004883EC20E800000000}
append/dup live-call-direct-bytes #{90} 64
append live-call-direct-bytes #{C9C3}
rs-o2-ir/set-direct-body-range 19 88
live-call-selected: rs-o2-ir/finish-function reduce [
	live-call-direct-bytes
	reduce [live-call-relocs]
	1100
]
unless empty? rs-o2-x64/call-spilled-values [
	fail rejoin ["live scalar was unnecessarily call-spilled: " mold rs-o2-x64/call-spilled-values]
]
unless rs-o2-x64/used-callee-save-registers = [ebx] [
	fail rejoin ["live scalar did not use EBX: " mold rs-o2-x64/used-callee-save-registers]
]
unless rs-o2-x64/callee-save-offsets = [ebx -40] [fail "EBX save slot is wrong"]
unless all [
	rs-o2-x64/fixed-shadow-frame-merge?
	find live-call-selected/1 #{4883EC30}
	not find live-call-selected/1 #{4883EC10}
][
	fail rejoin ["callee-save frame was not merged into shadow space: " mold live-call-selected/1]
]
unless find live-call-selected/1 #{48895DD8} [fail "EBX was not saved before the call"]
unless find live-call-selected/1 #{488B5DD8} [fail "EBX was not restored after the call"]
unless live-call-relocs/1 > 1120 [fail "live-value call relocation was not moved"]

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
unless empty? rs-o2-x64/call-spilled-values [
	fail rejoin ["first call result was unnecessarily spilled: " mold rs-o2-x64/call-spilled-values]
]
unless empty? rs-o2-x64/call-split-values [
	fail rejoin ["integer call result was unnecessarily split: " mold rs-o2-x64/call-split-values]
]
unless rs-o2-x64/used-callee-save-registers = [ebx] [
	fail rejoin ["first call result did not use EBX: " mold rs-o2-x64/used-callee-save-registers]
]
unless find two-call-selected/1 #{89C3} [fail "first call result was not moved from EAX to EBX"]
unless all [first-live-relocs/1 > 1201 second-live-relocs/1 > 1206] [
	fail "two-call relocations were not moved"
]

unless rs-o2-ir/begin-function 'two-address-spill-legalization 'win64 i32 %machine-ir-smoke.red [
	fail "two-address spill legalization function did not start"
]
rs-o2-ir/add-stack-object 'date 'argument i32 4 4 'none
rs-o2-ir/set-stack-offset 'date -8
two-address-date-a: rs-o2-ir/emit-load-local 'date i32
two-address-days: rs-o2-ir/emit-call 'two-address-days-callee reduce [two-address-date-a] i32
two-address-date-b: rs-o2-ir/emit-load-local 'date i32
two-address-year: rs-o2-ir/emit-call 'two-address-year-callee reduce [two-address-date-b] i32
two-address-result: rs-o2-ir/emit-binary
	rs-o2-ir/subtract-op
	two-address-days
	two-address-year
	i32
	'pure
two-address-one: rs-o2-ir/emit-constant 1 i32
two-address-result: rs-o2-ir/emit-binary
	rs-o2-ir/add-op
	two-address-result
	two-address-one
	i32
	'pure
rs-o2-ir/set-direct-body-range 0 10
two-address-days-relocs: reduce [1801]
two-address-year-relocs: reduce [1806]
put emitter/symbols 'two-address-days-callee reduce ['native none two-address-days-relocs]
put emitter/symbols 'two-address-year-callee reduce ['native none two-address-year-relocs]
two-address-direct: reduce [
	#{E800000000E800000000}
	reduce [two-address-days-relocs two-address-year-relocs]
	1800
]
two-address-selected: rs-o2-ir/finish-function two-address-direct
if two-address-selected/1 = two-address-direct/1 [
	fail "two-address spill legalization retained direct code"
]
unless find two-address-selected/1 #{29C389D8} [
	fail rejoin [
		"two-address callee-save sequence is missing: "
		mold two-address-selected/1
	]
]
unless all [two-address-days-relocs/1 > 1801 two-address-year-relocs/1 > 1806] [
	fail "two-address selected relocations were not moved"
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
register-clobber-relocs: reduce [1401]
register-consumer-relocs: reduce [1406]
put emitter/symbols 'register-clobber-callee reduce ['native none register-clobber-relocs]
put emitter/symbols 'register-consumer-callee reduce ['native none register-consumer-relocs]
register-argument-direct-bytes: copy #{E800000000E800000000}
append/dup register-argument-direct-bytes #{90} 64
rs-o2-ir/set-direct-body-range 0 74
register-argument-selected: rs-o2-ir/finish-function reduce [
	register-argument-direct-bytes
	reduce [register-clobber-relocs register-consumer-relocs]
	1400
]
unless empty? rs-o2-x64/call-spilled-values [
	fail rejoin [
		"register arguments used unnecessary call spills: "
		mold rs-o2-x64/call-spilled-values
	]
]
unless rs-o2-x64/call-split-values = reduce [live-register-float] [
	fail rejoin [
		"live XMM argument did not split around the call: "
		mold rs-o2-x64/call-split-values
	]
]
unless all [
	find register-argument-selected/1 #{F20F1145D0E8}
	find register-argument-selected/1 #{F20F1045D089D9F20F10C8E8}
][
	fail rejoin [
		"register arguments did not use a split XMM spill and ABI copies: "
		mold register-argument-selected/1
	]
]
unless all [register-clobber-relocs/1 > 1401 register-consumer-relocs/1 > 1406] [
	fail "register-argument call relocations were not moved"
]

unless rs-o2-ir/begin-function 'call-live-expansion-fallback 'win64 i32 %machine-ir-smoke.red [
	fail "call-live expansion fallback function did not start"
]
rs-o2-ir/add-stack-object 'fallback-value 'argument i32 4 4 'none
rs-o2-ir/set-stack-offset 'fallback-value -8
fallback-live-value: rs-o2-ir/emit-load-local 'fallback-value i32
rs-o2-ir/emit-call 'fallback-clobber-callee copy [] none
fallback-consumer-result: rs-o2-ir/emit-call
	'fallback-consumer-callee
	reduce [fallback-live-value]
	i32
rs-o2-ir/set-direct-body-range 0 10
fallback-clobber-relocs: reduce [1451]
fallback-consumer-relocs: reduce [1456]
put emitter/symbols 'fallback-clobber-callee reduce ['native none fallback-clobber-relocs]
put emitter/symbols 'fallback-consumer-callee reduce ['native none fallback-consumer-relocs]
call-live-expansion-direct: reduce [
	#{E800000000E800000000}
	reduce [fallback-clobber-relocs fallback-consumer-relocs]
	1450
]
call-live-expansion-selected: rs-o2-ir/finish-function call-live-expansion-direct
unless call-live-expansion-selected/1 = call-live-expansion-direct/1 [
	fail "expanded call-live body did not retain direct code"
]
unless rs-o2-x64/released-call-argument-fixed? [
	fail "call-live ABI argument hint was not released before profitability fallback"
]

unless rs-o2-ir/begin-function 'global-scalar-roundtrip 'win64 i32 %machine-ir-smoke.red [
	fail "global scalar function did not start"
]
global-scalar-load: rs-o2-ir/emit-load-global 'global-scalar i32
global-scalar-one: rs-o2-ir/emit-constant 1 i32
global-scalar-result: rs-o2-ir/emit-binary
	rs-o2-ir/add-op
	global-scalar-load
	global-scalar-one
	i32
	'pure
rs-o2-ir/emit-store-global 'global-scalar global-scalar-result i32
global-scalar-final: rs-o2-ir/emit-load-global 'global-scalar i32
rs-o2-ir/set-direct-body-range 15 33
global-scalar-relocs: reduce [1517 1523 1529]
put emitter/symbols 'global-scalar reduce ['global 0 global-scalar-relocs]
global-scalar-selected: rs-o2-ir/finish-function reduce [
	#{554889E56A006A0068000000006A008B05000000008905000000008B0500000000C9C3}
	reduce [global-scalar-relocs next global-scalar-relocs skip global-scalar-relocs 2]
	1500
]
unless global-scalar-selected/1 = #{8B050000000083C0018905000000008B0500000000C3} [
	fail rejoin ["global scalar bytes are wrong: " mold global-scalar-selected/1]
]
unless global-scalar-relocs = [1502 1511 1517] [
	fail rejoin ["global scalar relocations are wrong: " mold global-scalar-relocs]
]

unless rs-o2-ir/begin-function 'reordered-global-relocations 'win64 i32 %machine-ir-smoke.red [
	fail "reordered global relocation function did not start"
]
reordered-global-a: rs-o2-ir/emit-load-global 'reordered-global-a i32
reordered-global-b: rs-o2-ir/emit-load-global 'reordered-global-b i32
reordered-global-result: rs-o2-ir/emit-binary
	rs-o2-ir/add-op
	reordered-global-a
	reordered-global-b
	i32
	'pure
rs-o2-ir/set-direct-body-range 0 12
reordered-global-a-relocs: reduce [2508]
reordered-global-b-relocs: reduce [2502]
put emitter/symbols 'reordered-global-a reduce ['global 0 reordered-global-a-relocs]
put emitter/symbols 'reordered-global-b reduce ['global 0 reordered-global-b-relocs]
reordered-global-selected: rs-o2-ir/finish-function reduce [
	#{000000000000000000000000}
	reduce [reordered-global-b-relocs reordered-global-a-relocs]
	2500
]
unless reordered-global-selected/1 = #{8B05000000008B0D000000008D0408C3} [
	fail rejoin ["reordered global relocation bytes are wrong: " mold reordered-global-selected/1]
]
unless all [
	reordered-global-a-relocs = [2502]
	reordered-global-b-relocs = [2508]
][
	fail rejoin [
		"reordered global relocation patches are wrong: "
		mold reduce [reordered-global-a-relocs reordered-global-b-relocs]
	]
]

unless rs-o2-ir/begin-function 'global-pointer-roundtrip 'win64 ptr-type %machine-ir-smoke.red [
	fail "global pointer function did not start"
]
global-pointer-load: rs-o2-ir/emit-load-global 'global-pointer ptr-type
rs-o2-ir/emit-store-global 'global-pointer global-pointer-load ptr-type
rs-o2-ir/set-direct-body-range 15 29
global-pointer-relocs: reduce [1818 1825]
put emitter/symbols 'global-pointer reduce ['global 0 global-pointer-relocs]
global-pointer-selected: rs-o2-ir/finish-function reduce [
	#{554889E56A006A0068000000006A00488B050000000048890500000000C9C3}
	reduce [global-pointer-relocs next global-pointer-relocs]
	1800
]
unless global-pointer-selected/1 = #{488B050000000048890500000000C3} [
	fail rejoin ["global pointer bytes are wrong: " mold global-pointer-selected/1]
]
unless global-pointer-relocs = [1803 1810] [
	fail rejoin ["global pointer relocations are wrong: " mold global-pointer-relocs]
]

unless rs-o2-ir/begin-function 'global-float-roundtrip 'win64 f64 %machine-ir-smoke.red [
	fail "global float function did not start"
]
rs-o2-ir/add-stack-object 'global-float-value 'argument f64 8 8 'none
rs-o2-ir/set-stack-offset 'global-float-value -40
global-float-value: rs-o2-ir/emit-load-local 'global-float-value f64
rs-o2-ir/emit-store-global 'global-float global-float-value f64
global-float-load: rs-o2-ir/emit-load-global 'global-float f64
rs-o2-ir/set-direct-body-range 15 31
global-float-relocs: reduce [1919 1927]
put emitter/symbols 'global-float reduce ['global 0 global-float-relocs]
global-float-selected: rs-o2-ir/finish-function reduce [
	#{554889E56A006A0068000000006A00F20F110500000000F20F100500000000C9C3}
	reduce [global-float-relocs next global-float-relocs]
	1900
]
unless global-float-selected/1 = #{F20F110500000000F20F100500000000C3} [
	fail rejoin ["global float bytes are wrong: " mold global-float-selected/1]
]
unless global-float-relocs = [1904 1912] [
	fail rejoin ["global float relocations are wrong: " mold global-float-relocs]
]

unless rs-o2-ir/begin-function 'global-loop-fallback 'win64 i32 %machine-ir-smoke.red [
	fail "global loop fallback function did not start"
]
rs-o2-ir/add-stack-object 'global-loop-index 'local i32 4 4 'none
rs-o2-ir/set-stack-offset 'global-loop-index -40
global-loop-zero: rs-o2-ir/emit-constant 0 i32
rs-o2-ir/emit-store-local 'global-loop-index global-loop-zero i32
global-loop-state: rs-o2-ir/begin-while
global-loop-index: rs-o2-ir/emit-load-local 'global-loop-index i32
global-loop-limit: rs-o2-ir/emit-constant 4 i32
global-loop-test: rs-o2-ir/emit-binary
	rs-o2-ir/less-op
	global-loop-index
	global-loop-limit
	logic-type
	'pure
rs-o2-ir/while-condition global-loop-state
global-loop-value: rs-o2-ir/emit-load-global 'global-loop-scalar i32
global-loop-one: rs-o2-ir/emit-constant 1 i32
global-loop-value: rs-o2-ir/emit-binary
	rs-o2-ir/add-op
	global-loop-value
	global-loop-one
	i32
	'pure
rs-o2-ir/emit-store-global 'global-loop-scalar global-loop-value i32
global-loop-index: rs-o2-ir/emit-load-local 'global-loop-index i32
global-loop-index: rs-o2-ir/emit-binary
	rs-o2-ir/add-op
	global-loop-index
	global-loop-one
	i32
	'pure
rs-o2-ir/emit-store-local 'global-loop-index global-loop-index i32
rs-o2-ir/end-while global-loop-state
global-loop-result: rs-o2-ir/emit-load-local 'global-loop-index i32
rs-o2-ir/set-direct-body-range 0 1
global-loop-direct: reduce [#{CC} copy []]
global-loop-selected: rs-o2-ir/finish-function global-loop-direct
unless global-loop-selected/1 = #{CC} [fail "global loop did not retain direct code"]

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
unless (copy skip emitter/bits-buf 16) = #{01000000010000000100000001000000} [
	fail rejoin ["extended GC bitmap is wrong: " mold emitter/bits-buf]
]
unless rs-o2-x64/gc-bitmap-list = [1 1 1 - 1] [
	fail rejoin ["planned GC bitmap is wrong: " mold rs-o2-x64/gc-bitmap-list]
]
unless rs-o2-x64/gc-bitmap-offset = 4 [fail "GC bitmap word offset is wrong"]
unless all [
	empty? rs-o2-x64/call-spilled-values
	rs-o2-x64/call-split-values = reduce [gc-live-pointer]
][
	fail "managed pointer was not split across the call"
]

clear emitter/bits-buf
foreach bitmap-word [1 0 0 0] [
	append emitter/bits-buf int-to-bin/to-bin32 bitmap-word
]
unless rs-o2-ir/begin-function 'gc-handle-across-call 'win64 i32 %machine-ir-smoke.red [
	fail "gc-handle-across-call function did not start"
]
rs-o2-ir/set-frame-bitmap-offset 0
rs-o2-ir/add-stack-object 'handle-value 'argument handle-type 4 4 'handle
rs-o2-ir/set-stack-offset 'handle-value -40
gc-live-handle: rs-o2-ir/emit-load-local 'handle-value handle-type
gc-handle-inner-result: rs-o2-ir/emit-call 'gc-handle-clobber-callee copy [] i32
gc-handle-outer-result: rs-o2-ir/emit-call
	'gc-handle-consumer-callee
	reduce [gc-live-handle gc-handle-inner-result]
	i32
rs-o2-ir/set-direct-body-range 15 25
gc-handle-clobber-relocs: reduce [1666]
gc-handle-consumer-relocs: reduce [1671]
put emitter/symbols 'gc-handle-clobber-callee reduce ['native none gc-handle-clobber-relocs]
put emitter/symbols 'gc-handle-consumer-callee reduce ['native none gc-handle-consumer-relocs]
gc-handle-selected: rs-o2-ir/finish-function reduce [
	#{554889E56A006A0068000000006A00E800000000E800000000C9C3}
	reduce [gc-handle-clobber-relocs gc-handle-consumer-relocs]
	1650
]
unless (copy/part at gc-handle-selected/1 10 4) = #{04000000} [
	fail rejoin ["handle GC bitmap prologue offset was not patched: " mold gc-handle-selected/1]
]
unless (copy skip emitter/bits-buf 16) = #{01000000010000000000000000000000} [
	fail rejoin ["extended handle GC bitmap is wrong: " mold emitter/bits-buf]
]
unless rs-o2-x64/gc-bitmap-list = [1 1 0 - 0] [
	fail rejoin ["planned handle GC bitmap is wrong: " mold rs-o2-x64/gc-bitmap-list]
]
unless all [
	empty? rs-o2-x64/call-spilled-values
	rs-o2-x64/call-split-values = reduce [gc-live-handle]
][
	fail "managed handle was not split across the call"
]

clear emitter/bits-buf
foreach bitmap-word [1 0 1 0] [
	append emitter/bits-buf int-to-bin/to-bin32 bitmap-word
]
unless rs-o2-ir/begin-function 'gc-pointer-across-resolver 'win64 ptr-type %machine-ir-smoke.red [
	fail "gc-pointer-across-resolver function did not start"
]
rs-o2-ir/set-frame-bitmap-offset 0
rs-o2-ir/add-stack-object 'pointer-value 'argument ptr-type 8 8 'pointer
rs-o2-ir/add-stack-object 'handle 'argument i32 4 4 'none
rs-o2-ir/set-stack-offset 'pointer-value -40
rs-o2-ir/set-stack-offset 'handle -48
gc-resolver-live-pointer: rs-o2-ir/emit-load-local 'pointer-value ptr-type
gc-resolver-handle: rs-o2-ir/emit-load-local 'handle i32
gc-resolver-result: rs-o2-ir/emit-resolver
	'red>resolve-series
	gc-resolver-handle
	ptr-type
rs-o2-ir/set-last-result gc-resolver-live-pointer ptr-type
rs-o2-ir/set-direct-body-range 15 25
gc-resolver-registry-relocs: reduce [1716]
gc-resolver-call-relocs: reduce [1721]
put emitter/symbols 'red>node-registry reduce ['global none gc-resolver-registry-relocs]
put emitter/symbols 'red>resolve-series reduce ['native none gc-resolver-call-relocs]
gc-resolver-selected: rs-o2-ir/finish-function reduce [
	#{554889E56A006A0068000000006A0000000000000000000000C9C3}
	reduce [gc-resolver-registry-relocs gc-resolver-call-relocs]
	1700
]
unless all [
	empty? rs-o2-x64/call-spilled-values
	find rs-o2-x64/call-split-values gc-resolver-live-pointer
][
	fail rejoin [
		"managed pointer was not split across resolve-series: "
		mold reduce [rs-o2-x64/call-spilled-values rs-o2-x64/call-split-values]
	]
]
unless all [
	gc-resolver-selected/1 <> #{554889E56A006A0068000000006A0000000000000000000000C9C3}
	find gc-resolver-selected/1 #{4885C0}
	find gc-resolver-selected/1 #{E800000000}
][fail rejoin ["GC resolver bytes are wrong: " mold gc-resolver-selected/1]]
unless rs-o2-x64/gc-bitmap-list = [1 2 1 - 2] [
	fail rejoin ["GC resolver bitmap is wrong: " mold rs-o2-x64/gc-bitmap-list]
]

unless rs-o2-ir/begin-function 'shift-left-immediate 'win64 i32 %machine-ir-smoke.red [
	fail "immediate left-shift function did not start"
]
rs-o2-ir/add-stack-object 'shift-value 'argument i32 4 4 'none
shift-left-value: rs-o2-ir/emit-load-local 'shift-value i32
shift-left-count: rs-o2-ir/emit-constant 7 i32
shift-left-result: rs-o2-ir/emit-binary
	rs-o2-ir/left-shift-op
	shift-left-value
	shift-left-count
	i32
	'pure
rs-o2-ir/set-direct-body-range 0 1
shift-left-selected: rs-o2-ir/finish-function reduce [#{CC} copy []]
unless shift-left-selected/1 = #{89C8C1E007C3} [
	fail rejoin ["immediate left-shift bytes are wrong: " mold shift-left-selected/1]
]

unless rs-o2-ir/begin-function 'shift-right-signed-immediate 'win64 i32 %machine-ir-smoke.red [
	fail "immediate signed right-shift function did not start"
]
rs-o2-ir/add-stack-object 'shift-value 'argument i32 4 4 'none
shift-right-value: rs-o2-ir/emit-load-local 'shift-value i32
shift-right-count: rs-o2-ir/emit-constant 3 i32
shift-right-result: rs-o2-ir/emit-binary
	rs-o2-ir/right-shift-op
	shift-right-value
	shift-right-count
	i32
	'pure
rs-o2-ir/set-direct-body-range 0 1
shift-right-selected: rs-o2-ir/finish-function reduce [#{CC} copy []]
unless shift-right-selected/1 = #{89C8C1F803C3} [
	fail rejoin ["immediate signed right-shift bytes are wrong: " mold shift-right-selected/1]
]

unless rs-o2-ir/begin-function 'shift-right-unsigned-immediate 'win64 i32 %machine-ir-smoke.red [
	fail "immediate unsigned right-shift function did not start"
]
rs-o2-ir/add-stack-object 'shift-value 'argument i32 4 4 'none
shift-unsigned-value: rs-o2-ir/emit-load-local 'shift-value i32
shift-unsigned-count: rs-o2-ir/emit-constant 3 i32
shift-unsigned-result: rs-o2-ir/emit-binary
	rs-o2-ir/unsigned-right-shift-op
	shift-unsigned-value
	shift-unsigned-count
	i32
	'pure
rs-o2-ir/set-direct-body-range 0 1
shift-unsigned-selected: rs-o2-ir/finish-function reduce [#{CC} copy []]
unless shift-unsigned-selected/1 = #{89C8C1E803C3} [
	fail rejoin ["immediate unsigned right-shift bytes are wrong: " mold shift-unsigned-selected/1]
]

unless rs-o2-ir/begin-function 'shift-variable-count 'win64 i32 %machine-ir-smoke.red [
	fail "variable-count shift function did not start"
]
rs-o2-ir/add-stack-object 'shift-value 'argument i32 4 4 'none
rs-o2-ir/add-stack-object 'shift-count 'argument i32 4 4 'none
rs-o2-ir/set-stack-offset 'shift-value -40
rs-o2-ir/set-stack-offset 'shift-count -48
shift-variable-value: rs-o2-ir/emit-load-local 'shift-value i32
shift-variable-count: rs-o2-ir/emit-load-local 'shift-count i32
shift-variable-result: rs-o2-ir/emit-binary
	rs-o2-ir/left-shift-op
	shift-variable-value
	shift-variable-count
	i32
	'pure
rs-o2-ir/set-direct-body-range 0 1
shift-variable-direct: reduce [#{CC} copy []]
shift-variable-selected: rs-o2-ir/finish-function shift-variable-direct
unless shift-variable-selected/1 = #{8B45D88B55D089D1D3E0} [
	fail rejoin ["variable-count shift bytes are wrong: " mold shift-variable-selected/1]
]

unless rs-o2-ir/begin-function 'log-b-intrinsic 'win64 i32 %machine-ir-smoke.red [
	fail "log-b intrinsic function did not start"
]
rs-o2-ir/add-stack-object 'log-b-value 'argument i32 4 4 'none
log-b-value: rs-o2-ir/emit-load-local 'log-b-value i32
log-b-result: rs-o2-ir/emit-log-b log-b-value i32
rs-o2-ir/set-direct-body-range 0 1
log-b-selected: rs-o2-ir/finish-function reduce [#{CC} copy []]
unless log-b-selected/1 = #{89C80FBDC0C3} [
	fail rejoin ["log-b intrinsic bytes are wrong: " mold log-b-selected/1]
]

unless rs-o2-ir/begin-function 'signed-divide-register 'win64 i32 %machine-ir-smoke.red [
	fail "signed register division function did not start"
]
rs-o2-ir/add-stack-object 'divide-left 'argument i32 4 4 'none
rs-o2-ir/add-stack-object 'divide-right 'argument i32 4 4 'none
rs-o2-ir/set-stack-offset 'divide-left -40
rs-o2-ir/set-stack-offset 'divide-right -48
divide-left: rs-o2-ir/emit-load-local 'divide-left i32
divide-right: rs-o2-ir/emit-load-local 'divide-right i32
divide-result: rs-o2-ir/emit-binary
	rs-o2-ir/divide-op
	divide-left
	divide-right
	i32
	'may-trap
rs-o2-ir/set-direct-body-range 0 1
divide-selected: rs-o2-ir/finish-function reduce [#{CC} copy []]
unless divide-selected/1 = #{448B45D8448B4DD04489C94489C099F7F9} [
	fail rejoin ["signed register division bytes are wrong: " mold divide-selected/1]
]

unless rs-o2-ir/begin-function 'signed-modulus-immediate 'win64 i32 %machine-ir-smoke.red [
	fail "signed immediate modulus function did not start"
]
rs-o2-ir/add-stack-object 'modulus-left 'argument i32 4 4 'none
rs-o2-ir/set-stack-offset 'modulus-left -40
modulus-left: rs-o2-ir/emit-load-local 'modulus-left i32
modulus-right: rs-o2-ir/emit-constant 10 i32
modulus-result: rs-o2-ir/emit-binary
	rs-o2-ir/modulo-op
	modulus-left
	modulus-right
	i32
	'may-trap
rs-o2-ir/set-direct-body-range 0 1
modulus-selected: rs-o2-ir/finish-function reduce [#{CC} copy []]
unless modulus-selected/1 = #{448B45D84489C0B967666666F7E989D0C1F8024489C2C1FA1F29D0B90A0000000FAFC14489C229C289D089C2C1FA1F21CA01D0} [
	fail rejoin ["signed immediate modulus bytes are wrong: " mold modulus-selected/1]
]

unless rs-o2-ir/begin-function 'signed-remainder-immediate 'win64 i32 %machine-ir-smoke.red [
	fail "signed immediate remainder function did not start"
]
rs-o2-ir/add-stack-object 'remainder-left 'argument i32 4 4 'none
rs-o2-ir/set-stack-offset 'remainder-left -40
remainder-left: rs-o2-ir/emit-load-local 'remainder-left i32
remainder-right: rs-o2-ir/emit-constant 10 i32
remainder-result: rs-o2-ir/emit-binary
	rs-o2-ir/remainder-op
	remainder-left
	remainder-right
	i32
	'may-trap
rs-o2-ir/set-direct-body-range 0 1
remainder-selected: rs-o2-ir/finish-function reduce [#{CC} copy []]
unless remainder-selected/1 = #{448B45D84489C0B967666666F7E989D0C1F8024489C2C1FA1F29D0B90A0000000FAFC14489C229C289D0} [
	fail rejoin ["signed immediate remainder bytes are wrong: " mold remainder-selected/1]
]

unless rs-o2-ir/begin-function 'float-member-after-call 'win64 f64 %machine-ir-smoke.red [
	fail "float member after call function did not start"
]
rs-o2-ir/add-stack-object 'item 'argument cell-ptr-type 8 8 'pointer
rs-o2-ir/set-stack-offset 'item -40
rs-o2-ir/add-stack-object 'divisor 'local f64 8 8 'none
rs-o2-ir/set-stack-offset 'divisor -48
float-member-call-item: rs-o2-ir/emit-load-local 'item cell-ptr-type
float-member-call-result: rs-o2-ir/emit-call 'float-member-callee reduce [float-member-call-item] f64
rs-o2-ir/emit-store-local 'divisor float-member-call-result f64
float-member-base: rs-o2-ir/emit-load-local 'item cell-ptr-type
float-member-value: rs-o2-ir/emit-load-indirect float-member-base 8 f64
float-member-divisor: rs-o2-ir/emit-load-local 'divisor f64
float-member-result: rs-o2-ir/emit-binary
	rs-o2-ir/divide-op
	float-member-value
	float-member-divisor
	f64
	'may-trap
rs-o2-ir/emit-store-indirect float-member-base 8 float-member-result f64
float-member-return-base: rs-o2-ir/emit-load-local 'item cell-ptr-type
float-member-return: rs-o2-ir/emit-load-indirect float-member-return-base 8 f64
rs-o2-ir/set-direct-body-range 0 5
float-member-relocs: reduce [2101]
put emitter/symbols 'float-member-callee reduce ['native none float-member-relocs]
float-member-selected: rs-o2-ir/finish-function reduce [
	#{E800000000} reduce [float-member-relocs] 2100
]
unless float-member-selected/1 = #{488B4DD8E800000000F20F1145D0488B4DD8F20F104908F20F5EC8F20F114908488B4DD8F20F104108} [
	fail rejoin ["float member after call bytes are wrong: " mold float-member-selected/1]
]

unless rs-o2-ir/begin-function 'fallback 'win64 none %machine-ir-smoke.red [
	fail "fallback function did not start"
]
rs-o2-ir/emit-opaque 'unsupported-smoke none
fallback-direct: reduce [#{CC} copy []]
fallback-selected: rs-o2-ir/finish-function fallback-direct
unless fallback-selected/1 = #{CC} [fail "fallback bytes changed"]
agg16: rs-o2-ir/make-type 'agg 8 'gpr no 16 'none
agg24: rs-o2-ir/make-type 'agg 8 'gpr no 24 'none

unless rs-o2-ir/begin-function 'aggregate-copy-op 'win64 agg16 %machine-ir-smoke.red [
	fail "aggregate copy function did not start"
]
rs-o2-ir/add-stack-object 'aggregate-copy-destination 'local agg16 16 8 'none
rs-o2-ir/add-stack-object 'aggregate-copy-source 'local agg16 16 8 'none
rs-o2-ir/set-stack-offset 'aggregate-copy-destination -16
rs-o2-ir/set-stack-offset 'aggregate-copy-source -32
aggregate-copy-destination: rs-o2-ir/emit-address-local 'aggregate-copy-destination agg16
aggregate-copy-source: rs-o2-ir/emit-address-local 'aggregate-copy-source agg16
aggregate-copy-result: rs-o2-ir/emit-copy-aggregate
	aggregate-copy-destination aggregate-copy-source agg16
rs-o2-ir/set-direct-body-range 0 1
aggregate-copy-op-selected: rs-o2-ir/finish-function reduce [#{CC} copy []]
unless aggregate-copy-op-selected/1 = #{488D45F0488D4DE04C8B194C89184C8B59084C895808} [
	fail rejoin ["aggregate copy operation bytes are wrong: " mold aggregate-copy-op-selected/1]
]

unless rs-o2-ir/begin-function 'aggregate-register-result 'win64 agg16 %machine-ir-smoke.red [
	fail "aggregate register-result function did not start"
]
aggregate-register-result: rs-o2-ir/emit-call/aggregate-result
	'aggregate-register-callee copy [] agg16 'register 16 none
rs-o2-ir/set-direct-body-range 0 5
aggregate-register-relocs: reduce [2201]
put emitter/symbols 'aggregate-register-callee reduce ['native none aggregate-register-relocs]
aggregate-register-selected: rs-o2-ir/finish-function reduce [
	#{E800000000} reduce [aggregate-register-relocs] 2200
]
unless aggregate-register-selected/1 = #{4883EC30E80000000048894424204889542428488D442420} [
	fail rejoin ["aggregate register result bytes are wrong: " mold aggregate-register-selected/1]
]

unless rs-o2-ir/begin-function 'aggregate-hidden-result 'win64 agg24 %machine-ir-smoke.red [
	fail "aggregate hidden-result function did not start"
]
aggregate-hidden-temp: rs-o2-ir/emit-aggregate-temp 24
aggregate-hidden-pointer: rs-o2-ir/emit-bitcast aggregate-hidden-temp ptr-type
aggregate-hidden-result: rs-o2-ir/emit-call/aggregate-result
	'aggregate-hidden-callee reduce [aggregate-hidden-pointer] agg24
	'hidden 24 aggregate-hidden-temp
rs-o2-ir/set-direct-body-range 0 5
aggregate-hidden-relocs: reduce [2301]
put emitter/symbols 'aggregate-hidden-callee reduce ['native none aggregate-hidden-relocs]
aggregate-hidden-selected: rs-o2-ir/finish-function reduce [
	#{E800000000} reduce [aggregate-hidden-relocs] 2300
]
unless aggregate-hidden-selected/1 = #{4883EC40488D4424204889C1E800000000488D442420} [
	fail rejoin ["aggregate hidden result bytes are wrong: " mold aggregate-hidden-selected/1]
]

unless rs-o2-ir/begin-function 'sysv-aggregate-register-argument 'sysv i32 %machine-ir-smoke.red [
	fail "SysV aggregate register-argument function did not start"
]
rs-o2-ir/add-stack-object 'sysv-register-aggregate 'local agg16 16 8 'none
rs-o2-ir/set-stack-offset 'sysv-register-aggregate -16
sysv-register-aggregate: rs-o2-ir/emit-address-local 'sysv-register-aggregate agg16
sysv-register-integer: rs-o2-ir/emit-load-aggregate-slot/abi-class
	sysv-register-aggregate 0 8 'integer
sysv-register-sse: rs-o2-ir/emit-load-aggregate-slot/abi-class
	sysv-register-aggregate 8 8 'sse
sysv-register-groups: make block! 1
append/only sysv-register-groups reduce [
	'start 1 'count 2 'mode 'register-or-stack
	'classes [integer sse] 'size 16
]
sysv-register-result: rs-o2-ir/emit-call/argument-groups
	'sysv-register-aggregate-callee
	reduce [sysv-register-integer sysv-register-sse]
	i32
	sysv-register-groups
rs-o2-ir/set-direct-body-range 0 5
sysv-register-relocs: reduce [2401]
put emitter/symbols 'sysv-register-aggregate-callee reduce ['import none sysv-register-relocs]
sysv-register-selected: rs-o2-ir/finish-function reduce [
	#{E800000000} reduce [sysv-register-relocs] 2400
]
unless (last rs-o2-x64/call-argument-locations) = [edi xmm0] [
	fail rejoin [
		"SysV mixed aggregate register locations are wrong: "
		mold last rs-o2-x64/call-argument-locations
	]
]
if sysv-register-selected/1 = #{E800000000} [
	fail "SysV mixed aggregate register call fell back"
]

unless rs-o2-ir/begin-function 'sysv-aggregate-register-rollback 'sysv i32 %machine-ir-smoke.red [
	fail "SysV aggregate register rollback function did not start"
]
sysv-rollback-values: make block! 8
repeat sysv-rollback-index 5 [
	append sysv-rollback-values rs-o2-ir/emit-constant sysv-rollback-index i32
]
rs-o2-ir/add-stack-object 'sysv-rollback-aggregate 'local agg16 16 8 'none
rs-o2-ir/set-stack-offset 'sysv-rollback-aggregate -16
sysv-rollback-aggregate: rs-o2-ir/emit-address-local 'sysv-rollback-aggregate agg16
append sysv-rollback-values rs-o2-ir/emit-load-aggregate-slot/abi-class
	sysv-rollback-aggregate 0 8 'integer
append sysv-rollback-values rs-o2-ir/emit-load-aggregate-slot/abi-class
	sysv-rollback-aggregate 8 8 'integer
append sysv-rollback-values rs-o2-ir/emit-constant 6 i32
sysv-rollback-groups: make block! 1
append/only sysv-rollback-groups reduce [
	'start 6 'count 2 'mode 'register-or-stack
	'classes [integer integer] 'size 16
]
sysv-rollback-result: rs-o2-ir/emit-call/argument-groups
	'sysv-rollback-callee sysv-rollback-values i32 sysv-rollback-groups
rs-o2-ir/set-direct-body-range 0 5
sysv-rollback-relocs: reduce [2501]
put emitter/symbols 'sysv-rollback-callee reduce ['import none sysv-rollback-relocs]
sysv-rollback-selected: rs-o2-ir/finish-function reduce [
	#{E800000000} reduce [sysv-rollback-relocs] 2500
]
unless (last rs-o2-x64/call-argument-locations) = [edi esi edx ecx r8d 0 8 r9d] [
	fail rejoin [
		"SysV aggregate register rollback locations are wrong: "
		mold last rs-o2-x64/call-argument-locations
	]
]
unless rs-o2-x64/outgoing-frame-bytes = 16 [
	fail rejoin ["SysV aggregate rollback frame is wrong: " rs-o2-x64/outgoing-frame-bytes]
]
if sysv-rollback-selected/1 = #{E800000000} [
	fail "SysV aggregate register rollback call fell back"
]

unless rs-o2-ir/begin-function 'sysv-mixed-aggregate-result 'sysv agg16 %machine-ir-smoke.red [
	fail "SysV mixed aggregate-result function did not start"
]
sysv-mixed-aggregate-result: rs-o2-ir/emit-call/aggregate-result/result-classes
	'sysv-mixed-aggregate-result-callee copy [] agg16
	'sysv-register 16 none [sse integer]
rs-o2-ir/set-direct-body-range 0 5
sysv-mixed-result-relocs: reduce [2601]
put emitter/symbols 'sysv-mixed-aggregate-result-callee reduce ['import none sysv-mixed-result-relocs]
sysv-mixed-result-selected: rs-o2-ir/finish-function reduce [
	#{E800000000} reduce [sysv-mixed-result-relocs] 2600
]
unless sysv-mixed-result-selected/1 = #{4883E4F04883EC10E800000000F20F1104244889442408488D0424} [
	fail rejoin ["SysV mixed aggregate result bytes are wrong: " mold sysv-mixed-result-selected/1]
]

unless rs-o2-ir/begin-function 'win64-typed-list 'win64 i32 %machine-ir-smoke.red [
	fail "Win64 typed-list function did not start"
]
typed-i8-value: rs-o2-ir/emit-constant -2 i8
typed-i64-value: rs-o2-ir/emit-constant #{FFFFFFFF00000000} i64
typed-f64-value: rs-o2-ir/emit-constant 1.5 f64
typed-values: reduce [typed-i8-value typed-i64-value typed-f64-value]
typed-list: rs-o2-ir/emit-typed-list typed-values [13 11 5]
typed-list-instruction: rs-o2-ir/find-vreg-definition typed-list
typed-count: rs-o2-ir/emit-constant 3 i32
typed-result: rs-o2-ir/emit-call 'typed-list-callee reduce [typed-count typed-list] i32
rs-o2-ir/emit-keepalive typed-values
rs-o2-ir/set-direct-body-range 0 5
typed-relocs: reduce [2701]
put emitter/symbols 'typed-list-callee reduce ['native none typed-relocs]
typed-selected: rs-o2-ir/finish-function reduce [
	#{E800000000} reduce [typed-relocs] 2700
]
unless rs-o2-x64/outgoing-frame-bytes = 112 [
	fail rejoin ["Win64 typed-list frame is wrong: " rs-o2-x64/outgoing-frame-bytes]
]
unless 32 = rs-o2-ir/table-value rs-o2-x64/aggregate-temp-offsets
	pick typed-list-instruction rs-o2-ir/ins-id
[
	fail "Win64 typed-list temporary offset is wrong"
]
unless find typed-selected/1 #{E800000000} [
	fail rejoin ["Win64 typed-list call is missing: " mold typed-selected/1]
]

unless rs-o2-ir/begin-function 'win64-import-pointer-load 'win64 ptr-type %machine-ir-smoke.red [
	fail "Win64 import pointer load function did not start"
]
win64-import-pointer-result: rs-o2-ir/emit-load-global 'win64-import-pointer ptr-type
rs-o2-ir/set-direct-body-range 0 10
win64-import-pointer-relocs: reduce [2801]
put emitter/symbols 'win64-import-pointer reduce ['import-var none win64-import-pointer-relocs]
win64-import-pointer-selected: rs-o2-ir/finish-function reduce [
	#{00000000000000000000} reduce [win64-import-pointer-relocs] 2800
]
unless win64-import-pointer-selected/1 = #{488B0500000000488B00C3} [
	fail rejoin [
		"Win64 import pointer load bytes are wrong: "
		mold win64-import-pointer-selected/1
	]
]

unless rs-o2-ir/begin-function 'win64-import-integer-store 'win64 i32 %machine-ir-smoke.red [
	fail "Win64 import integer store function did not start"
]
rs-o2-ir/add-stack-object 'value 'argument i32 4 4 'none
win64-import-store-value: rs-o2-ir/emit-load-local 'value i32
rs-o2-ir/emit-store-global 'win64-import-integer win64-import-store-value i32
rs-o2-ir/set-direct-body-range 0 12
win64-import-store-relocs: reduce [2901]
put emitter/symbols 'win64-import-integer reduce ['import-var none win64-import-store-relocs]
win64-import-store-selected: rs-o2-ir/finish-function reduce [
	#{000000000000000000000000} reduce [win64-import-store-relocs] 2900
]
unless win64-import-store-selected/1 = #{4C8B1D0000000041890B89C8C3} [
	fail rejoin [
		"Win64 import integer store bytes are wrong: "
		mold win64-import-store-selected/1
	]
]

unless rs-o2-ir/begin-function 'sysv-import-float-load 'sysv f64 %machine-ir-smoke.red [
	fail "SysV import float load function did not start"
]
sysv-import-float-result: rs-o2-ir/emit-load-global 'sysv-import-float f64
rs-o2-ir/set-direct-body-range 0 12
sysv-import-float-relocs: reduce [3001]
put emitter/symbols 'sysv-import-float reduce ['import-var none sysv-import-float-relocs]
sysv-import-float-selected: rs-o2-ir/finish-function reduce [
	#{000000000000000000000000} reduce [sysv-import-float-relocs] 3000
]
unless sysv-import-float-selected/1 = #{4C8B1D00000000F2410F1003C3} [
	fail rejoin [
		"SysV import float load bytes are wrong: "
		mold sysv-import-float-selected/1
	]
]

unless rs-o2-ir/begin-function 'win64-explicit-return-dead 'win64 i32 %machine-ir-smoke.red [
	fail "Win64 explicit return function did not start"
]
explicit-return-value: rs-o2-ir/emit-constant 7 i32
rs-o2-ir/emit-source-return yes
explicit-return-dead: rs-o2-ir/emit-constant 99 i32
rs-o2-ir/set-direct-body-range 0 1
explicit-return-selected: rs-o2-ir/finish-function reduce [#{CC} copy []]
unless explicit-return-selected/1 = #{B807000000C3} [
	fail rejoin ["Win64 explicit return bytes are wrong: " mold explicit-return-selected/1]
]

unless rs-o2-ir/begin-function 'sysv-explicit-return-branch 'sysv i32 %machine-ir-smoke.red [
	fail "SysV branch return function did not start"
]
rs-o2-ir/add-stack-object 'value 'argument i32 4 4 'none
rs-o2-ir/set-stack-offset 'value -8
explicit-branch-state: rs-o2-ir/begin-if
explicit-branch-value: rs-o2-ir/emit-load-local 'value i32
explicit-branch-zero: rs-o2-ir/emit-constant 0 i32
explicit-branch-condition: rs-o2-ir/emit-binary
	rs-o2-ir/less-op
	explicit-branch-value
	explicit-branch-zero
	logic-type
	'pure
rs-o2-ir/if-condition explicit-branch-state
explicit-branch-return: rs-o2-ir/emit-constant -11 i32
rs-o2-ir/emit-source-return yes
rs-o2-ir/end-if explicit-branch-state
explicit-branch-fallthrough: rs-o2-ir/emit-constant 22 i32
rs-o2-ir/set-direct-body-range 0 1
explicit-branch-selected: rs-o2-ir/finish-function reduce [#{CC} copy []]
if explicit-branch-selected/1 = #{CC} [fail "SysV branch return fell back"]

unless rs-o2-ir/begin-function 'win64-either-return 'win64 i32 %machine-ir-smoke.red [
	fail "Win64 either return function did not start"
]
rs-o2-ir/add-stack-object 'value 'argument i32 4 4 'none
rs-o2-ir/set-stack-offset 'value -8
either-return-state: rs-o2-ir/begin-either
either-return-value: rs-o2-ir/emit-load-local 'value i32
either-return-zero: rs-o2-ir/emit-constant 0 i32
either-return-condition: rs-o2-ir/emit-binary
	rs-o2-ir/less-op
	either-return-value
	either-return-zero
	logic-type
	'pure
rs-o2-ir/either-condition either-return-state
either-return-early: rs-o2-ir/emit-constant -5 i32
rs-o2-ir/emit-source-return yes
rs-o2-ir/end-either-true either-return-state
either-return-fallthrough: rs-o2-ir/emit-constant 9 i32
either-return-result: rs-o2-ir/end-either either-return-state
unless either-return-result [fail "either return value was not merged"]
rs-o2-ir/set-direct-body-range 0 1
either-return-selected: rs-o2-ir/finish-function reduce [#{CC} copy []]
if either-return-selected/1 = #{CC} [fail "Win64 either return fell back"]

unless rs-o2-ir/begin-function 'win64-overflow-dual-constant 'win64 logic-type %machine-ir-smoke.red [
	fail "Win64 dual-constant overflow function did not start"
]
dual-overflow-state: rs-o2-ir/begin-overflow
dual-overflow-maximum: rs-o2-ir/emit-constant 2147483647 i32
dual-overflow-one: rs-o2-ir/emit-constant 1 i32
dual-overflow-result: rs-o2-ir/emit-source-binary
	rs-o2-ir/add-op
	dual-overflow-maximum
	dual-overflow-one
	i32
	'pure
dual-overflow-flag: rs-o2-ir/end-overflow dual-overflow-state
dual-constant-info: rs-o2-x64/constant-use-info
if find dual-constant-info/2 dual-overflow-maximum [
	fail "both constant operands were elided as immediates"
]
unless find dual-constant-info/2 dual-overflow-one [
	fail "right constant operand was not selected as the immediate"
]
rs-o2-ir/set-direct-body-range 0 1
dual-overflow-selected: rs-o2-ir/finish-function reduce [#{CC} copy []]
if dual-overflow-selected/1 = #{CC} [fail "Win64 dual-constant overflow fell back"]
unless find dual-overflow-selected/1 #{FFFFFF7F} [
	fail "left overflow constant was not materialized"
]

unless rs-o2-ir/begin-function 'win64-overflow-store-commit 'win64 i32 %machine-ir-smoke.red [
	fail "Win64 overflow store-commit function did not start"
]
rs-o2-ir/add-stack-object 'commit-value 'local i32 4 4 'none
rs-o2-ir/set-stack-offset 'commit-value -8
commit-initial: rs-o2-ir/emit-constant 2147483647 i32
rs-o2-ir/emit-store-local 'commit-value commit-initial i32
commit-overflow-state: rs-o2-ir/begin-overflow
commit-loaded: rs-o2-ir/emit-load-local 'commit-value i32
commit-one: rs-o2-ir/emit-constant 1 i32
commit-sum: rs-o2-ir/emit-source-binary
	rs-o2-ir/add-op commit-loaded commit-one i32 'pure
rs-o2-ir/emit-store-local 'commit-value commit-sum i32
commit-store-block: pick rs-o2-ir/current rs-o2-ir/fn-current-block
commit-store-instruction: last pick commit-store-block rs-o2-ir/bb-instructions
commit-overflow-flag: rs-o2-ir/end-overflow commit-overflow-state
commit-result: rs-o2-ir/emit-load-local 'commit-value i32
rs-o2-ir/set-direct-body-range 0 1
commit-direct-chunk: reduce [#{CC} copy []]
unless rs-o2-x64/validate-current commit-direct-chunk [
	fail "Win64 overflow store-commit validation failed"
]
commit-promoted-register: rs-o2-x64/promoted-register 'commit-value
unless commit-promoted-register [fail "overflow store-commit local was not promoted"]
if rs-o2-x64/store-target-coalescing-safe?
	commit-store-block commit-store-instruction 'commit-value commit-sum
[
	fail "control-edge store was considered safe to commit early"
]
commit-intervals: rs-o2-x64/build-intervals
commit-sum-interval: rs-o2-x64/find-interval commit-intervals commit-sum
unless commit-sum-interval [fail "overflow store result interval is missing"]
if (pick commit-sum-interval rs-o2-x64/interval-fixed) = commit-promoted-register [
	fail "overflow store result was precolored to the promoted local"
]
commit-selected: rs-o2-ir/finish-function commit-direct-chunk
if commit-selected/1 = #{CC} [fail "Win64 overflow store-commit fell back"]

unless rs-o2-ir/begin-function 'win64-handle-arithmetic-coercion 'win64 i32 none [
	fail "handle arithmetic coercion function did not start"
]
rs-o2-ir/add-stack-object 'coercion-handle 'argument handle-type 4 4 'handle
rs-o2-ir/add-stack-object 'coercion-value 'argument i32 4 4 'none
rs-o2-ir/add-stack-object 'coercion-result 'local handle-type 4 4 'handle
rs-o2-ir/set-stack-offset 'coercion-handle -40
rs-o2-ir/set-stack-offset 'coercion-value -48
rs-o2-ir/set-stack-offset 'coercion-result -8
coercion-handle: rs-o2-ir/emit-load-local 'coercion-handle handle-type
coercion-value: rs-o2-ir/emit-load-local 'coercion-value i32
coercion-sum: rs-o2-ir/emit-source-binary
	rs-o2-ir/add-op coercion-handle coercion-value handle-type 'pure
coercion-sum-type: rs-o2-ir/vreg-type coercion-sum
unless all [coercion-sum-type coercion-sum-type/6 = 'none][
	fail "handle arithmetic result retained GC identity"
]
coercion-stored: rs-o2-ir/emit-store-local 'coercion-result coercion-sum handle-type
coercion-stored-type: rs-o2-ir/vreg-type coercion-stored
unless coercion-stored-type/6 = 'handle [
	fail "handle assignment did not restore GC identity"
]
coercion-result: rs-o2-ir/emit-load-local 'coercion-result handle-type
rs-o2-ir/set-direct-body-range 0 1
coercion-selected: rs-o2-ir/finish-function reduce [#{CC} copy []]
if coercion-selected/1 = #{CC} [fail "handle arithmetic coercion fell back"]

unless rs-o2-ir/begin-function 'relocation-value-numbering 'win64 ptr-type none [
	fail "relocation value-numbering function did not start"
]
relocation-address-first: rs-o2-ir/emit-address-global 'relocation-global ptr-type
relocation-address-second: rs-o2-ir/emit-address-global 'relocation-global ptr-type
rs-o2-ir/emit-return relocation-address-second
rs-o2-ir/pass-local-value-numbering
relocation-address-copy: rs-o2-ir/find-instruction 2
unless (pick relocation-address-copy rs-o2-ir/ins-opcode) = 'copy [
	fail "duplicate global address was not value-numbered"
]
relocation-value-numbering-relocs: pick rs-o2-ir/current rs-o2-ir/fn-relocations
unless all [
	(length? relocation-value-numbering-relocs) = 1
	relocation-value-numbering-relocs/1/1 = 1
][
	fail rejoin [
		"rewritten global-address relocation was retained: "
		mold relocation-value-numbering-relocs
	]
]
rs-o2-ir/rebuild-current-stack-dependencies
unless rs-o2-ir/verify-current [fail "value-numbered global address did not verify"]
rs-o2-ir/abort-function

unless rs-o2-ir/begin-function 'sysv-atomic-memory 'sysv i32 %machine-ir-smoke.red [
	fail "SysV atomic memory function did not start"
]
rs-o2-ir/add-stack-object 'atomic-address 'argument ptr-type 8 8 'pointer
rs-o2-ir/add-stack-object 'atomic-value 'argument i32 4 4 'none
atomic-address: rs-o2-ir/emit-load-local 'atomic-address ptr-type
atomic-value: rs-o2-ir/emit-load-local 'atomic-value i32
rs-o2-ir/emit-atomic-store atomic-address atomic-value i32
foreach operation [add sub or xor and] [
	atomic-address: rs-o2-ir/emit-load-local 'atomic-address ptr-type
	atomic-value: rs-o2-ir/emit-load-local 'atomic-value i32
	rs-o2-ir/emit-atomic-math operation atomic-address atomic-value no no i32
]
atomic-address: rs-o2-ir/emit-load-local 'atomic-address ptr-type
atomic-result: rs-o2-ir/emit-atomic-load atomic-address i32
rs-o2-ir/emit-atomic-fence
rs-o2-ir/emit-return atomic-result
rs-o2-ir/set-direct-body-range 0 1
atomic-memory-selected: rs-o2-ir/finish-function reduce [#{CC} copy []]
if atomic-memory-selected/1 = #{CC} [fail "SysV atomic memory function fell back"]
foreach encoding [
	#{458913} #{F0450113} #{F0452913} #{F0450913} #{F0453113} #{F0452113} #{0FAEF0}
][
	unless find atomic-memory-selected/1 encoding [
		fail rejoin ["SysV atomic memory encoding is missing: " mold encoding]
	]
]

unless rs-o2-ir/begin-function 'win64-atomic-xadd 'win64 i32 %machine-ir-smoke.red [
	fail "Win64 atomic XADD function did not start"
]
rs-o2-ir/add-stack-object 'xadd-address 'argument ptr-type 8 8 'pointer
rs-o2-ir/add-stack-object 'xadd-value 'argument i32 4 4 'none
xadd-address: rs-o2-ir/emit-load-local 'xadd-address ptr-type
xadd-value: rs-o2-ir/emit-load-local 'xadd-value i32
xadd-old: rs-o2-ir/emit-atomic-math 'add xadd-address xadd-value yes yes i32
xadd-address: rs-o2-ir/emit-load-local 'xadd-address ptr-type
xadd-value: rs-o2-ir/emit-load-local 'xadd-value i32
xadd-new: rs-o2-ir/emit-atomic-math 'sub xadd-address xadd-value no yes i32
rs-o2-ir/emit-return xadd-new
rs-o2-ir/set-direct-body-range 0 1
atomic-xadd-selected: rs-o2-ir/finish-function reduce [#{CC} copy []]
if atomic-xadd-selected/1 = #{CC} [fail "Win64 atomic XADD function fell back"]
unless find atomic-xadd-selected/1 #{F0410FC103} [fail "atomic XADD instruction is missing"]
unless find atomic-xadd-selected/1 #{F7D8} [fail "atomic subtraction negation is missing"]

unless rs-o2-ir/begin-function 'win64-atomic-bitwise-result 'win64 i32 %machine-ir-smoke.red [
	fail "Win64 returned bitwise atomic function did not start"
]
rs-o2-ir/add-stack-object 'bitwise-address 'argument ptr-type 8 8 'pointer
rs-o2-ir/add-stack-object 'bitwise-value 'argument i32 4 4 'none
bitwise-address: rs-o2-ir/emit-load-local 'bitwise-address ptr-type
bitwise-value: rs-o2-ir/emit-load-local 'bitwise-value i32
bitwise-result: rs-o2-ir/emit-atomic-math 'or bitwise-address bitwise-value no yes i32
rs-o2-ir/emit-return bitwise-result
rs-o2-ir/set-direct-body-range 0 1
atomic-bitwise-selected: rs-o2-ir/finish-function reduce [#{CC} copy []]
if atomic-bitwise-selected/1 = #{CC} [fail "Win64 returned bitwise atomic function fell back"]
unless find atomic-bitwise-selected/1 #{F0410FB11375} [
	fail "returned bitwise atomic CAS loop is missing"
]

unless rs-o2-ir/begin-function 'win64-atomic-cas 'win64 logic-type %machine-ir-smoke.red [
	fail "Win64 atomic CAS function did not start"
]
rs-o2-ir/add-stack-object 'cas-address 'argument ptr-type 8 8 'pointer
rs-o2-ir/add-stack-object 'cas-check 'argument i32 4 4 'none
rs-o2-ir/add-stack-object 'cas-value 'argument i32 4 4 'none
cas-address: rs-o2-ir/emit-load-local 'cas-address ptr-type
cas-check: rs-o2-ir/emit-load-local 'cas-check i32
cas-value: rs-o2-ir/emit-load-local 'cas-value i32
cas-result: rs-o2-ir/emit-atomic-cas cas-address cas-check cas-value yes logic-type
rs-o2-ir/emit-return cas-result
rs-o2-ir/set-direct-body-range 0 1
atomic-cas-selected: rs-o2-ir/finish-function reduce [#{CC} copy []]
if atomic-cas-selected/1 = #{CC} [fail "Win64 atomic CAS function fell back"]
unless find atomic-cas-selected/1 #{F0450FB113} [fail "atomic CMPXCHG instruction is missing"]
unless find atomic-cas-selected/1 #{0F94} [fail "atomic CAS boolean materialization is missing"]

unless rs-o2-ir/begin-function 'verifier-invalid-atomic-metadata 'win64 i32 none [
	fail "invalid-atomic-metadata verifier function did not start"
]
rs-o2-ir/add-stack-object 'invalid-atomic-address 'argument ptr-type 8 8 'pointer
invalid-atomic-address: rs-o2-ir/emit-load-local 'invalid-atomic-address ptr-type
invalid-atomic-value: rs-o2-ir/emit-constant 1 i32
invalid-atomic-result: rs-o2-ir/emit-atomic-math
	'add invalid-atomic-address invalid-atomic-value no yes i32
rs-o2-ir/emit-return invalid-atomic-result
invalid-atomic-instruction: rs-o2-ir/find-instruction 3
invalid-atomic-metadata: pick invalid-atomic-instruction rs-o2-ir/ins-metadata
invalid-atomic-operation: find invalid-atomic-metadata 'operation
invalid-atomic-operation/2: 'multiply
if rs-o2-ir/verify-current [fail "verifier accepted invalid atomic metadata"]
unless find pick rs-o2-ir/current rs-o2-ir/fn-verifier-errors
	"invalid atomic metadata in instruction 3"
[
	fail "invalid atomic metadata verifier error missing"
]
rs-o2-ir/abort-function

unless rs-o2-ir/begin-function 'verifier-undefined-flags 'win64 i32 none [
	fail "undefined-flags verifier function did not start"
]
undefined-flags-true: rs-o2-ir/add-block 'true
undefined-flags-false: rs-o2-ir/add-block 'false
rs-o2-ir/set-current-block 1
undefined-flags-left: rs-o2-ir/emit-constant 1 i32
undefined-flags-right: rs-o2-ir/emit-constant 2 i32
undefined-flags-condition: rs-o2-ir/emit-binary
	rs-o2-ir/less-op
	undefined-flags-left
	undefined-flags-right
	logic-type
	'pure
rs-o2-ir/emit-branch
	undefined-flags-condition
	pick undefined-flags-true rs-o2-ir/bb-id
	pick undefined-flags-false rs-o2-ir/bb-id
undefined-flags-entry: pick (pick rs-o2-ir/current rs-o2-ir/fn-blocks) 1
undefined-flags-branch: last pick undefined-flags-entry rs-o2-ir/bb-instructions
poke undefined-flags-branch rs-o2-ir/ins-flags-in 999
rs-o2-ir/set-current-block pick undefined-flags-true rs-o2-ir/bb-id
undefined-flags-value: rs-o2-ir/emit-constant 1 i32
rs-o2-ir/emit-return undefined-flags-value
rs-o2-ir/set-current-block pick undefined-flags-false rs-o2-ir/bb-id
undefined-flags-value: rs-o2-ir/emit-constant 0 i32
rs-o2-ir/emit-return undefined-flags-value
if rs-o2-ir/verify-current [fail "verifier accepted undefined flags"]
unless find pick rs-o2-ir/current rs-o2-ir/fn-verifier-errors "undefined flag use f999" [
	fail "undefined flag verifier error missing"
]
rs-o2-ir/abort-function

unless rs-o2-ir/begin-function 'verifier-clobbered-flags 'win64 i32 none [
	fail "clobbered-flags verifier function did not start"
]
clobbered-flags-true: rs-o2-ir/add-block 'true
clobbered-flags-false: rs-o2-ir/add-block 'false
rs-o2-ir/set-current-block 1
clobbered-flags-left: rs-o2-ir/emit-constant 1 i32
clobbered-flags-right: rs-o2-ir/emit-constant 2 i32
clobbered-flags-condition: rs-o2-ir/emit-binary
	rs-o2-ir/less-op
	clobbered-flags-left
	clobbered-flags-right
	logic-type
	'pure
clobbered-flags-other: rs-o2-ir/emit-binary
	rs-o2-ir/equal-op
	clobbered-flags-left
	clobbered-flags-right
	logic-type
	'pure
rs-o2-ir/emit-branch
	clobbered-flags-condition
	pick clobbered-flags-true rs-o2-ir/bb-id
	pick clobbered-flags-false rs-o2-ir/bb-id
rs-o2-ir/set-current-block pick clobbered-flags-true rs-o2-ir/bb-id
clobbered-flags-value: rs-o2-ir/emit-constant 1 i32
rs-o2-ir/emit-return clobbered-flags-value
rs-o2-ir/set-current-block pick clobbered-flags-false rs-o2-ir/bb-id
clobbered-flags-value: rs-o2-ir/emit-constant 0 i32
rs-o2-ir/emit-return clobbered-flags-value
if rs-o2-ir/verify-current [fail "verifier accepted clobbered flags"]
unless find pick rs-o2-ir/current rs-o2-ir/fn-verifier-errors "flag f1 is not live at instruction 5" [
	fail "clobbered flag verifier error missing"
]
rs-o2-ir/abort-function

unless rs-o2-ir/begin-function 'verifier-cross-block-flags 'win64 i32 none [
	fail "cross-block-flags verifier function did not start"
]
cross-block-flags-consumer: rs-o2-ir/add-block 'consumer
cross-block-flags-true: rs-o2-ir/add-block 'true
cross-block-flags-false: rs-o2-ir/add-block 'false
rs-o2-ir/set-current-block 1
cross-block-flags-left: rs-o2-ir/emit-constant 1 i32
cross-block-flags-right: rs-o2-ir/emit-constant 2 i32
cross-block-flags-condition: rs-o2-ir/emit-binary
	rs-o2-ir/less-op
	cross-block-flags-left
	cross-block-flags-right
	logic-type
	'pure
rs-o2-ir/emit-jump pick cross-block-flags-consumer rs-o2-ir/bb-id
rs-o2-ir/set-current-block pick cross-block-flags-consumer rs-o2-ir/bb-id
rs-o2-ir/emit-branch
	cross-block-flags-condition
	pick cross-block-flags-true rs-o2-ir/bb-id
	pick cross-block-flags-false rs-o2-ir/bb-id
rs-o2-ir/set-current-block pick cross-block-flags-true rs-o2-ir/bb-id
cross-block-flags-value: rs-o2-ir/emit-constant 1 i32
rs-o2-ir/emit-return cross-block-flags-value
rs-o2-ir/set-current-block pick cross-block-flags-false rs-o2-ir/bb-id
cross-block-flags-value: rs-o2-ir/emit-constant 0 i32
rs-o2-ir/emit-return cross-block-flags-value
if rs-o2-ir/verify-current [fail "verifier accepted cross-block flags"]
unless find pick rs-o2-ir/current rs-o2-ir/fn-verifier-errors
	"flag f1 crosses basic block at instruction 5"
[
	fail "cross-block flag verifier error missing"
]
rs-o2-ir/abort-function

unless rs-o2-ir/begin-function 'verifier-missing-memory-input 'win64 i32 none [
	fail "missing-memory-input verifier function did not start"
]
rs-o2-ir/add-stack-object 'memory-input-value 'argument i32 4 4 'none
missing-memory-result: rs-o2-ir/emit-load-local 'memory-input-value i32
rs-o2-ir/emit-return missing-memory-result
missing-memory-instruction: rs-o2-ir/find-instruction 1
poke missing-memory-instruction rs-o2-ir/ins-memory-in copy []
if rs-o2-ir/verify-current [fail "verifier accepted missing memory input"]
unless find pick rs-o2-ir/current rs-o2-ir/fn-verifier-errors
	"memory input dependency mismatch in instruction 1 expected=[universal 0 memory-input-value 0] actual=[]"
[
	fail "missing memory input verifier error missing"
]
rs-o2-ir/abort-function

unless rs-o2-ir/begin-function 'verifier-duplicate-memory-version 'win64 i32 none [
	fail "duplicate-memory-version verifier function did not start"
]
rs-o2-ir/add-stack-object 'memory-a 'local i32 4 4 'none
rs-o2-ir/add-stack-object 'memory-b 'local i32 4 4 'none
duplicate-memory-value: rs-o2-ir/emit-constant 1 i32
rs-o2-ir/emit-store-local 'memory-a duplicate-memory-value i32
rs-o2-ir/emit-store-local 'memory-b duplicate-memory-value i32
rs-o2-ir/emit-return duplicate-memory-value
duplicate-memory-store: rs-o2-ir/find-instruction 3
poke duplicate-memory-store rs-o2-ir/ins-memory-out reduce [
	'universal 0 'memory-b 1
]
if rs-o2-ir/verify-current [fail "verifier accepted duplicate memory version"]
unless find pick rs-o2-ir/current rs-o2-ir/fn-verifier-errors
	"duplicate memory definition m1 in instruction 3"
[
	fail "duplicate memory version verifier error missing"
]
rs-o2-ir/abort-function

unless rs-o2-ir/begin-function 'verifier-invalid-effect-alias 'win64 i32 none [
	fail "invalid-effect-alias verifier function did not start"
]
invalid-effect-value: rs-o2-ir/emit-constant 1 i32
rs-o2-ir/emit-return invalid-effect-value
invalid-effect-instruction: rs-o2-ir/find-instruction 1
poke invalid-effect-instruction rs-o2-ir/ins-alias 'universal
if rs-o2-ir/verify-current [fail "verifier accepted invalid effect alias"]
unless find pick rs-o2-ir/current rs-o2-ir/fn-verifier-errors
	"non-memory effect has alias universal in instruction 1"
[
	fail "invalid effect alias verifier error missing"
]
rs-o2-ir/abort-function

unless rs-o2-ir/begin-function 'verifier-invalid-memory-merge 'win64 i32 none [
	fail "invalid-memory-merge verifier function did not start"
]
invalid-memory-merge-block: rs-o2-ir/add-block 'merge
rs-o2-ir/set-current-block 1
rs-o2-ir/emit-jump pick invalid-memory-merge-block rs-o2-ir/bb-id
rs-o2-ir/set-current-block pick invalid-memory-merge-block rs-o2-ir/bb-id
invalid-memory-merge-value: rs-o2-ir/emit-constant 1 i32
rs-o2-ir/emit-return invalid-memory-merge-value
poke invalid-memory-merge-block rs-o2-ir/bb-memory-in reduce ['universal 0]
if rs-o2-ir/verify-current [fail "verifier accepted invalid memory merge"]
unless find pick rs-o2-ir/current rs-o2-ir/fn-verifier-errors
	"invalid memory merge into block 2"
[
	fail "invalid memory merge verifier error missing"
]
rs-o2-ir/abort-function

unless rs-o2-ir/begin-function 'verifier-invalid-call-metadata 'win64 i32 none [
	fail "invalid-call-metadata verifier function did not start"
]
invalid-call-result: rs-o2-ir/emit-call 'invalid-call-callee copy [] i32
rs-o2-ir/emit-return invalid-call-result
invalid-call-instruction: rs-o2-ir/find-instruction 1
invalid-call-metadata: pick invalid-call-instruction rs-o2-ir/ins-metadata
invalid-call-abi: find invalid-call-metadata 'abi
invalid-call-abi/2: 'sysv
if rs-o2-ir/verify-current [fail "verifier accepted invalid call metadata"]
unless find pick rs-o2-ir/current rs-o2-ir/fn-verifier-errors
	"invalid call metadata in instruction 1"
[
	fail "invalid call metadata verifier error missing"
]
rs-o2-ir/abort-function

unless rs-o2-ir/begin-function 'verifier-invalid-safepoint-root 'win64 i32 none [
	fail "invalid-safepoint-root verifier function did not start"
]
invalid-safepoint-result: rs-o2-ir/emit-call 'invalid-safepoint-callee copy [] i32
rs-o2-ir/emit-return invalid-safepoint-result
rs-o2-ir/add-safepoint 1 reduce [
	reduce ['vreg invalid-safepoint-result 'frame -8 'pointer]
]
if rs-o2-ir/verify-current [fail "verifier accepted invalid safepoint root"]
unless find pick rs-o2-ir/current rs-o2-ir/fn-verifier-errors
	"invalid safepoint root at instruction 1"
[
	fail "invalid safepoint root verifier error missing"
]
rs-o2-ir/abort-function

unless rs-o2-ir/begin-function 'verifier-stack-underflow 'win64 i32 none [
	fail "stack-underflow verifier function did not start"
]
stack-underflow-result: rs-o2-ir/emit-stack-pop i32
rs-o2-ir/emit-return stack-underflow-result
rs-o2-ir/rebuild-current-stack-dependencies
if rs-o2-ir/verify-current [fail "verifier accepted explicit stack underflow"]
unless find pick rs-o2-ir/current rs-o2-ir/fn-verifier-errors
	"stack underflow in instruction 1"
[
	fail "explicit stack underflow verifier error missing"
]
rs-o2-ir/abort-function

unless rs-o2-ir/begin-function 'verifier-stack-edge-mismatch 'win64 i32 none [
	fail "stack-edge-mismatch verifier function did not start"
]
stack-edge-true: rs-o2-ir/add-block 'true
stack-edge-false: rs-o2-ir/add-block 'false
stack-edge-merge: rs-o2-ir/add-block 'merge
rs-o2-ir/set-current-block 1
stack-edge-left: rs-o2-ir/emit-constant 1 i32
stack-edge-right: rs-o2-ir/emit-constant 2 i32
stack-edge-condition: rs-o2-ir/emit-binary
	rs-o2-ir/less-op
	stack-edge-left
	stack-edge-right
	logic-type
	'pure
rs-o2-ir/emit-branch
	stack-edge-condition
	pick stack-edge-true rs-o2-ir/bb-id
	pick stack-edge-false rs-o2-ir/bb-id
rs-o2-ir/set-current-block pick stack-edge-true rs-o2-ir/bb-id
stack-edge-value: rs-o2-ir/emit-constant 7 i32
rs-o2-ir/emit-stack-push stack-edge-value
rs-o2-ir/emit-jump pick stack-edge-merge rs-o2-ir/bb-id
rs-o2-ir/set-current-block pick stack-edge-false rs-o2-ir/bb-id
rs-o2-ir/emit-jump pick stack-edge-merge rs-o2-ir/bb-id
rs-o2-ir/set-current-block pick stack-edge-merge rs-o2-ir/bb-id
stack-edge-result: rs-o2-ir/emit-constant 9 i32
rs-o2-ir/emit-return stack-edge-result
rs-o2-ir/rebuild-current-stack-dependencies
if rs-o2-ir/verify-current [fail "verifier accepted mismatched CFG stack depths"]
unless find pick rs-o2-ir/current rs-o2-ir/fn-verifier-errors
	"stack depth mismatch on edge b3->b4"
[
	fail "CFG stack-depth mismatch verifier error missing"
]
rs-o2-ir/abort-function

unless rs-o2-ir/begin-function 'verifier-invalid-custom-call-metadata 'win64 i32 none [
	fail "invalid-custom-call-metadata verifier function did not start"
]
invalid-custom-count: rs-o2-ir/emit-constant 0 i32
invalid-custom-result: rs-o2-ir/emit-custom-call
	'invalid-custom-callee no 0 invalid-custom-count i32
rs-o2-ir/emit-return invalid-custom-result
rs-o2-ir/rebuild-current-stack-dependencies
invalid-custom-instruction: rs-o2-ir/find-instruction 2
invalid-custom-metadata: pick invalid-custom-instruction rs-o2-ir/ins-metadata
invalid-custom-count-kind: find invalid-custom-metadata 'count-kind
invalid-custom-count-kind/2: 'invalid
if rs-o2-ir/verify-current [fail "verifier accepted invalid custom call metadata"]
unless find pick rs-o2-ir/current rs-o2-ir/fn-verifier-errors
	"invalid custom call metadata in instruction 2"
[
	fail "invalid custom call metadata verifier error missing"
]
rs-o2-ir/abort-function

unless rs-o2-ir/begin-function 'verifier-symbolic-stack-call 'win64 i32 none [
	fail "symbolic-stack-call verifier function did not start"
]
rs-o2-ir/add-stack-object 'symbolic-count 'argument i32 4 4 'none
symbolic-count: rs-o2-ir/emit-load-local 'symbolic-count i32
symbolic-value: rs-o2-ir/emit-constant 7 i32
rs-o2-ir/emit-stack-push symbolic-value
symbolic-custom-result: rs-o2-ir/emit-custom-call
	'symbolic-custom-callee no none symbolic-count i32
symbolic-call-result: rs-o2-ir/emit-call 'symbolic-ordinary-callee copy [] i32
rs-o2-ir/emit-return symbolic-call-result
rs-o2-ir/rebuild-current-stack-dependencies
if rs-o2-ir/verify-current [fail "verifier accepted ABI call with symbolic stack depth"]
unless find pick rs-o2-ir/current rs-o2-ir/fn-verifier-errors
	"ABI call with active explicit stack in instruction 5"
[
	fail "symbolic stack ABI-call verifier error missing"
]
rs-o2-ir/abort-function

unless (pick rs-o2-ir/stats rs-o2-ir/stats-functions) = 106 [fail "final function count"]
unless (pick rs-o2-ir/stats rs-o2-ir/stats-verified) = 106 [fail "final verification count"]
unless (pick rs-o2-ir/stats rs-o2-ir/stats-eligible) = 105 [fail "final eligibility count"]
unless (pick rs-o2-ir/stats rs-o2-ir/stats-selected) = 102 [fail "final selection count"]
unless (pick rs-o2-ir/stats rs-o2-ir/stats-fallback) = 4 [fail "final fallback count"]

rs-o2-ir/end-session
dump-text: read dump-path
unless none? find dump-text "eligible=false selected=true" [
	fail "ineligible function was emitted as selected code"
]
unless find dump-text "passes:" [fail "pass log missing"]
unless find dump-text "dead-local-stores 6 5" [fail "dead local store was not removed"]
unless find dump-text "dead-code-elimination 5 2" [fail "dead code was not removed"]
unless find dump-text "%3:i32 = const 3" [fail "constant expression was not folded"]
unless find dump-text "unreachable-blocks 11 8" [fail "constant branch block was not removed"]
unless find dump-text "dead-code-elimination 8 5" [fail "constant branch compare was not removed"]
unless find dump-text "rip-rel32 global-scalar addend=0" [fail "global relocation dump missing"]
unless find dump-text "call-rel32 callee addend=0" [fail "call relocation dump missing"]
unless find dump-text "allocation: [1 ebx 2 eax 3 eax 4 ebx 5 ebx 6 edx 7 r8d 8 eax]" [
	fail "promoted call argument allocation dump is wrong"
]
if find dump-text "x64-two-address-conflict" [fail "two-address spill legalization fell back"]
unless find dump-text "x64-global-store-loop" [fail "global loop fallback reason missing"]
unless find dump-text "x64-pointer-immediate-range" [fail "pointer immediate fallback reason missing"]
unless find dump-text "x64-call-live-expansion" [fail "call-live profitability fallback reason missing"]
unless find dump-text "ptr8x16/pointer = +" [fail "16-byte pointer scale dump missing"]
unless find dump-text "switch %1, -550, b2" [fail "sparse switch dump missing"]
unless find dump-text " = phi b2," [fail "switch phi dump missing"]
unless find dump-text "switch %1, 0, b2, 1, b3" [fail "dense switch dump missing"]
unless find dump-text "resolve-node red>resolve-node" [fail "resolve-node dump missing"]
unless find dump-text "resolve-series red>resolve-series" [fail "resolve-series dump missing"]
unless find dump-text "i2 call-rel32 red>resolve-series" [fail "resolver slow-call relocation dump missing"]
unless find dump-text "gc=handle frame=-40" [fail "managed handle stack type missing"]
unless find dump-text "roots=[[vreg 1 frame -48 handle]]" [fail "managed handle safepoint missing"]
unless find dump-text "log-b %1" [fail "log-b intrinsic dump missing"]
unless find dump-text "function win64-explicit-return-dead" [fail "explicit return dump missing"]
unless find dump-text "function sysv-explicit-return-branch" [fail "branch return dump missing"]
unless find dump-text "function win64-either-return" [fail "either return dump missing"]
unless find dump-text "function win64-overflow-dual-constant" [fail "overflow constant dump missing"]
unless find dump-text "function win64-overflow-store-commit" [fail "overflow store dump missing"]
unless find dump-text "function win64-handle-arithmetic-coercion" [
	fail "handle arithmetic coercion dump missing"
]
unless find dump-text "atomic=[order seq-cst operation add" [fail "atomic metadata dump missing"]
print "machine-ir-smoke-ok"
