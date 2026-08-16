Red [
	Title: "Typed postfix Red/System frontend tests"
]

do %../../../compiler/rsir-frontend.red

frontend: compiler-rsir-frontend

assert: func [condition [logic!] message [string! block!]][
	unless condition [
		print ["FAIL:" either block? message [rejoin message][message]]
		quit/return 1
	]
]

word-at: func [data [binary!] offset [integer!] /local high][
	high: to integer! pick data (offset + 4)
	(to integer! pick data (offset + 1))
		+ ((to integer! pick data (offset + 2)) * 256)
		+ ((to integer! pick data (offset + 3)) * 65536)
		+ ((either high > 127 [high - 256][high]) * 16777216)
]

compile-text: func [text [string!] kind [word!] /limit max [integer!]][
	either limit [frontend/compile/limit load text kind max][
		frontend/compile load text kind
	]
]

; Offsets are derived from counts, so adding an unrelated record does not
; turn semantic tests into whole-image byte-offset tests.
layout-of: func [ir [binary!] /local types imports functions globals members
	type-at member-count import-at global-at function-at use-count use-at
	instruction-at strings-at id record
][
	types: word-at ir 8
	imports: word-at ir 12
	functions: word-at ir 16
	globals: word-at ir 24
	type-at: 28
	member-count: 0
	id: 0
	while [id < types][
		member-count: member-count + word-at ir (type-at + (id * 20) + 16)
		id: id + 1
	]
	import-at: type-at + (types * 20) + (member-count * 8)
	global-at: import-at + (imports * 32)
	function-at: global-at + (globals * 20)
	use-count: 0
	id: 0
	while [id < imports][
		use-count: use-count + word-at ir (import-at + (id * 32) + 28)
		id: id + 1
	]
	id: 0
	while [id < functions][
		record: function-at + (id * 36)
		use-count: use-count + word-at ir (record + 20)
		use-count: use-count + word-at ir (record + 28)
		id: id + 1
	]
	use-at: function-at + (functions * 36)
	instruction-at: use-at + (use-count * 8)
	strings-at: instruction-at + ((word-at ir 20) * 16)
	reduce [type-at import-at global-at function-at use-at instruction-at strings-at]
]

function-word: func [ir layout id field][
	word-at ir (layout/4 + ((id - 1) * 36) + field)
]

instruction-word: func [ir layout id field][
	word-at ir (layout/6 + ((id - 1) * 16) + field)
]

ops-of: func [ir layout /local output id count][
	output: make block! 16
	count: word-at ir 20
	id: 1
	while [id <= count][
		append output instruction-word ir layout id 0
		id: id + 1
	]
	output
]

void-ir: compile-text {Red/System [] fn: func [][]} 'user
assert binary? void-ir ["void function failed: " mold frontend/last-error]
void-layout: layout-of void-ir
assert all [
	(word-at void-ir 0) = 1
	(word-at void-ir 4) = 0
	(word-at void-ir 16) = 1
	(word-at void-ir 20) = 1
	(function-word void-ir void-layout 1 20) = 0
	(function-word void-ir void-layout 1 28) = 0
	(function-word void-ir void-layout 1 32) = 1
	(ops-of void-ir void-layout) = [11]
	(copy at void-ir (void-layout/7 + 1)) = #{666E}
]["void RSIR has the wrong semantic shape"]
assert void-ir = compile-text {Red/System [] fn: function [][]} 'user
	"func and function produced different IR"
assert void-ir = compile-text {
	Red/System []
	comment [hidden!: alias integer! hidden: func [][]]
	comment "ignored"
	fn: func [][]
} 'user "comments entered the semantic stream"

literal-ir: compile-text {
	Red/System []
	fn: func [return: [integer!]][7]
} 'user
literal-layout: layout-of literal-ir
assert all [
	(function-word literal-ir literal-layout 1 8) = -5
	(function-word literal-ir literal-layout 1 32) = 2
	(ops-of literal-ir literal-layout) = [1 11]
	(instruction-word literal-ir literal-layout 1 4) = -5
	(instruction-word literal-ir literal-layout 1 8) = 7
]["integer literal and return did not lower as typed postfix operations"]

local-ir: compile-text {
	Red/System []
	fn: func [return: [integer!] /local value][
		value: 7
		value
	]
} 'user
assert binary? local-ir ["inferred local failed: " mold frontend/last-error]
local-layout: layout-of local-ir
assert all [
	(function-word local-ir local-layout 1 16) = 0
	(function-word local-ir local-layout 1 20) = 0
	(function-word local-ir local-layout 1 24) = 0
	(function-word local-ir local-layout 1 28) = 1
	(function-word local-ir local-layout 1 32) = 7
	(word-at local-ir local-layout/5) = -5
	(ops-of local-ir local-layout) = [3 1 5 12 3 4 11]
	(instruction-word local-ir local-layout 1 4) = 1
	(instruction-word local-ir local-layout 1 8) = 1
]["local inference did not use the ordinary address/load/set model"]

explicit-local-ir: compile-text {
	Red/System []
	fn: func [return: [integer!] /local value [integer!]][value: 7]
} 'user
explicit-layout: layout-of explicit-local-ir
assert all [
	(function-word explicit-local-ir explicit-layout 1 28) = 1
	(ops-of explicit-local-ir explicit-layout) = [3 1 5 11]
]["assignment result was discarded inside the assignment operation"]

shadow-ir: compile-text {
	Red/System []
	value: 1
	fn: func [return: [integer!] /local value][value: 11 value]
} 'user
shadow-layout: layout-of shadow-ir
assert all [
	(word-at shadow-ir 24) = 1
	(instruction-word shadow-ir shadow-layout 1 4) = 1
	(instruction-word shadow-ir shadow-layout 1 8) = 1
]["a global captured a homonymous local"]

pointer-ir: compile-text {
	Red/System []
	int-ref!: alias pointer! [integer!]
	fn: func [
		a [int-ref!]
		b [int-ptr!]
		return: [int-ref!]
	][a]
} 'user
assert binary? pointer-ir ["parameterized pointer failed: " mold frontend/last-error]
pointer-layout: layout-of pointer-ir
assert all [
	(word-at pointer-ir 8) = 2
	(word-at pointer-ir pointer-layout/1) = -1
	(word-at pointer-ir (pointer-layout/1 + 4)) = 2
	(word-at pointer-ir (pointer-layout/1 + 20)) = -6
	(word-at pointer-ir (pointer-layout/1 + 24)) = -5
	(word-at pointer-ir pointer-layout/5) = 1
	(word-at pointer-ir (pointer-layout/5 + 8)) = 2
]["pointer aliases lost their canonical pointee type"]

assert binary? compile-text {
	Red/System []
	int-ref!: alias pointer! [integer!]
	fn: func [return: [int-ref!] /local value [int-ref!]][
		value: as pointer! [integer!] 0
		value
	]
} 'user "a pointer alias was incompatible with its canonical pointer type"

c-string-ir: compile-text {
	Red/System []
	fn: func [text [c-string!] return: [c-string!]][text]
} 'user
c-string-layout: layout-of c-string-ir
assert all [
	(function-word c-string-ir c-string-layout 1 8) = -13
	(word-at c-string-ir c-string-layout/5) = -13
]["c-string collapsed into an untyped pointer"]

call-ir: compile-text {
	Red/System []
	id: func [value [integer!] return: [integer!]][value]
	main: func [return: [integer!]][id id 9]
} 'user
call-layout: layout-of call-ir
assert all [
	(word-at call-ir 16) = 2
	(ops-of call-ir call-layout) = [3 4 11 1 7 7 11]
	(instruction-word call-ir call-layout 5 4) = 1
	(instruction-word call-ir call-layout 5 8) = 1
	(instruction-word call-ir call-layout 6 4) = 1
	(instruction-word call-ir call-layout 6 8) = 1
]["nested calls were not represented by one generic call operation"]

left-ir: compile-text {
	Red/System []
	fn: func [return: [integer!]][1 + 2 * 3]
} 'user
left-layout: layout-of left-ir
assert all [
	(ops-of left-ir left-layout) = [1 1 15 1 15 11]
	(instruction-word left-ir left-layout 3 4) = 1
	(instruction-word left-ir left-layout 5 4) = 3
]["ordinary operators did not fold strictly from left to right"]

paren-ir: compile-text {
	Red/System []
	fn: func [return: [integer!]][1 + (2 * 3)]
} 'user
paren-layout: layout-of paren-ir
assert all [
	(ops-of paren-ir paren-layout) = [1 1 1 15 15 11]
	(instruction-word paren-ir paren-layout 4 4) = 3
	(instruction-word paren-ir paren-layout 5 4) = 1
]["parentheses did not recurse through the ordinary expression emitter"]

prefix-ir: compile-text {
	Red/System []
	id: func [value [integer!] return: [integer!]][value]
	main: func [return: [integer!]][1 + id 2 * 3]
} 'user
prefix-layout: layout-of prefix-ir
assert all [
	(ops-of prefix-ir prefix-layout) = [3 4 11 1 1 1 15 7 15 11]
	(instruction-word prefix-ir prefix-layout 7 4) = 3
	(instruction-word prefix-ir prefix-layout 8 4) = 1
	(instruction-word prefix-ir prefix-layout 9 4) = 1
]["a prefix call argument did not retain its specified infix precedence"]

not-ir: compile-text {
	Red/System []
	fn: func [return: [logic!]][not 1 = 2]
} 'user
not-layout: layout-of not-ir
assert all [
	(ops-of not-ir not-layout) = [1 1 15 14 11]
	(instruction-word not-ir not-layout 3 4) = 13
	(instruction-word not-ir not-layout 4 4) = 1
]["not did not consume one complete prefix argument expression"]

byte-ir: compile-text {
	Red/System []
	fn: func [return: [byte!]][#"A"]
} 'user
byte-layout: layout-of byte-ir
assert all [
	(function-word byte-ir byte-layout 1 8) = -2
	(instruction-word byte-ir byte-layout 1 4) = -2
	(instruction-word byte-ir byte-layout 1 8) = 65
]["byte literal did not retain its logical byte type"]

glue-ir: compile-text {Red/System [] fn: func [][]} 'glue
glue-layout: layout-of glue-ir
assert all [
	(word-at glue-ir 0) = 3
	(word-at glue-ir 4) = 2
	(word-at glue-ir 16) = 2
	(word-at glue-ir 20) = 2
	(function-word glue-ir glue-layout 2 32) = 1
	(ops-of glue-ir glue-layout) = [11 11]
]["glue entry was not an ordinary function"]

assert none? compile-text {
	Red/System []
	fn: func [/local value][]
} 'user "an uninitialized untyped local was accepted"
assert frontend/last-error/code = frontend/ERROR-UNSUPPORTED
	"unresolved local reported the wrong error class"

assert none? compile-text {
	Red/System []
	fn: func [return: [integer!] /local value][value]
} 'user "an untyped local was read before inference"
assert frontend/last-error/code = frontend/ERROR-REFERENCE
	"uninitialized local read reported the wrong error class"

assert none? compile-text {
	Red/System []
	fn: func [value [pointer! [logic!]]][]
} 'user "pointer! accepted a pointee forbidden by the specification"
assert frontend/last-error/code = frontend/ERROR-UNSUPPORTED
	"invalid pointer pointee reported the wrong error class"

assert none? compile-text {
	Red/System []
	fn: func [/local value][value: 1 value: true]
} 'user "local inference allowed its type to change"
assert frontend/last-error/code = frontend/ERROR-REFERENCE
	"local type change reported the wrong error class"

assert none? compile-text {
	Red/System []
	fn: func [return: [integer!]][1 + true]
} 'user "integer arithmetic accepted a logic operand"
assert frontend/last-error/code = frontend/ERROR-REFERENCE
	"invalid binary operands reported the wrong error class"

assert none? compile-text/limit {Red/System [] fn: func [][]} 'user 32
	"frontend ignored its output limit"
assert frontend/last-error/code = frontend/ERROR-LIMIT
	"output limit reported the wrong error class"

assert none? compile-text {Red/System []} 'user
	"frontend accepted a module without a function"
assert frontend/last-error/code = frontend/ERROR-FUNCTION-COUNT
	"missing function reported the wrong error class"

print "PASS: typed postfix Red/System frontend"
