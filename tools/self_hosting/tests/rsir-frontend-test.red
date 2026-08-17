Red [
	Title: "Typed postfix Red/System frontend tests"
]

do %../../../compiler/rsir-frontend.red

frontend: compiler-rsir-frontend

assert: func [condition [logic! none!] message [string! block!]][
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
layout-of: func [ir [binary!] /local types imports functions globals switches members
	type-at member-count import-at global-at function-at use-count use-at
	initializer-count initializer-at switch-at instruction-at strings-at id record
][
	types: word-at ir 8
	imports: word-at ir 12
	functions: word-at ir 16
	globals: word-at ir 24
	switches: word-at ir 28
	type-at: 32
	member-count: 0
	id: 0
	while [id < types][
		if (word-at ir (type-at + (id * 20))) <> -7 [
			member-count: member-count + word-at ir (type-at + (id * 20) + 16)
		]
		id: id + 1
	]
	import-at: type-at + (types * 20) + (member-count * 8)
	global-at: import-at + (imports * 32)
	function-at: global-at + (globals * 24)
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
	initializer-count: 0
	id: 0
	while [id < globals][
		initializer-count: initializer-count
			+ word-at ir (global-at + (id * 24) + 20)
		id: id + 1
	]
	initializer-at: use-at + (use-count * 8)
	switch-at: initializer-at + (initializer-count * 16)
	instruction-at: switch-at + (switches * 12)
	strings-at: instruction-at + ((word-at ir 20) * 16)
	reduce [
		type-at import-at global-at function-at use-at instruction-at strings-at
		switch-at initializer-at
	]
]

function-word: func [ir layout id field][
	word-at ir (layout/4 + ((id - 1) * 36) + field)
]

type-word: func [ir layout id field][
	word-at ir (layout/1 + ((id - 1) * 20) + field)
]

member-word: func [ir layout id field][
	word-at ir (layout/1 + ((word-at ir 8) * 20) + ((id - 1) * 8) + field)
]

global-word: func [ir layout id field][
	word-at ir (layout/3 + ((id - 1) * 24) + field)
]

instruction-word: func [ir layout id field][
	word-at ir (layout/6 + ((id - 1) * 16) + field)
]

switch-word: func [ir layout id field][
	word-at ir (layout/8 + ((id - 1) * 12) + field)
]

initializer-word: func [ir layout id field][
	word-at ir (layout/9 + ((id - 1) * 16) + field)
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

pointer-cast-ir: compile-text {
	Red/System []
	to-bare: func [value [int-ptr!] return: [pointer!]][as pointer! value]
	to-typed: func [value [pointer!] return: [int-ptr!]][as int-ptr! value]
} 'user
assert binary? pointer-cast-ir [
	"explicit pointer casts failed: " mold frontend/last-error
]
pointer-cast-layout: layout-of pointer-cast-ir
assert (ops-of pointer-cast-ir pointer-cast-layout) = [3 4 8 11 3 4 8 11]
	"pointer pointee-changing casts were erased from the typed stream"

assert none? compile-text {
	Red/System []
	fn: func [value [pointer!] return: [int-ptr!]][value]
} 'user "an untyped pointer implicitly changed its pointee type"
assert frontend/last-error/code = frontend/ERROR-REFERENCE
	"implicit pointer pointee change reported the wrong error class"

c-string-ir: compile-text {
	Red/System []
	fn: func [text [c-string!] return: [c-string!]][text]
} 'user
c-string-layout: layout-of c-string-ir
assert all [
	(function-word c-string-ir c-string-layout 1 8) = -13
	(word-at c-string-ir c-string-layout/5) = -13
]["c-string collapsed into an untyped pointer"]

address-index-ir: compile-text {
	Red/System []
	fn: func [
		value [int64!]
		index [integer!]
		return: [integer!]
		/local p [int-ptr!]
	][
		p: as int-ptr! :value
		p/index: 7
		p/2
	]
} 'user
assert binary? address-index-ir [
	"address and index lowering failed: " mold frontend/last-error
]
address-index-layout: layout-of address-index-ir
assert all [
	(ops-of address-index-ir address-index-layout) = [
		3 3 20 8 5 12 3 4 3 4 21 1 5 12 3 4 21 4 11
	]
	(instruction-word address-index-ir address-index-layout 3 0) = 20
	(instruction-word address-index-ir address-index-layout 11 8) = 1
	(instruction-word address-index-ir address-index-layout 17 4) = 1
	(instruction-word address-index-ir address-index-layout 17 8) = 0
]["get-word and pointer indexes did not share REFERENCE/INDEX semantics"]

pointer-value-ir: compile-text {
	Red/System [] fn: func [p [int-ptr!] return: [integer!]][p/value]
} 'user
pointer-one-ir: compile-text {
	Red/System [] fn: func [p [int-ptr!] return: [integer!]][p/1]
} 'user
assert pointer-value-ir = pointer-one-ir
	"pointer/value is not exactly the same operation as pointer/1"

member-address-ir: compile-text {
	Red/System []
	pair!: alias struct! [left [integer!] right [byte!]]
	fn: func [pair [pair!] return: [int-ptr!]][:pair/right]
} 'user
assert binary? member-address-ir [
	"aggregate get-path lowering failed: " mold frontend/last-error
]
member-address-layout: layout-of member-address-ir
assert all [
	(ops-of member-address-ir member-address-layout) = [3 4 6 20 11]
	(instruction-word member-address-ir member-address-layout 3 4) = 1
	(instruction-word member-address-ir member-address-layout 4 0) = 20
]["aggregate get-path introduced a source-shaped address operation"]

scalar-declare-ir: compile-text {
	Red/System []
	fn: func [return: [integer!] /local value [integer!]][
		value: declare integer!
		value: 7
		value
	]
} 'user
assert binary? scalar-declare-ir [
	"scalar DECLARE failed: " mold frontend/last-error
]
scalar-declare-layout: layout-of scalar-declare-ir
assert (ops-of scalar-declare-ir scalar-declare-layout) = [3 1 5 12 3 4 11]
	"scalar DECLARE emitted runtime initialization"

local-declare-ir: compile-text {
	Red/System []
	pair!: alias struct! [left [integer!] right [integer!]]
	fn: func [return: [integer!] /local pair [pair!]][
		pair: declare pair!
		pair/left: 73
		pair/left
	]
} 'user
assert binary? local-declare-ir [
	"local aggregate DECLARE failed: " mold frontend/last-error
]
local-declare-layout: layout-of local-declare-ir
assert all [
	(function-word local-declare-ir local-declare-layout 1 28) = 2
	(word-at local-declare-ir (local-declare-layout/5 + 4)) = 0
	(word-at local-declare-ir (local-declare-layout/5 + 12)) = 1
	(copy/part ops-of local-declare-ir local-declare-layout 5) = [3 3 20 5 12]
]["local DECLARE did not expose one pointer variable over one inline object"]

inline-copy-ir: compile-text {
	Red/System []
	pair!: alias struct! [left [integer!] right [integer!]]
	box!: alias struct! [source [pair! value] target [pair! value]]
	fn: func [return: [integer!] /local box [box!]][
		box: declare box!
		box/source/left: 17
		box/target: box/source
		box/target/right: 29
		box/target/left + box/target/right
	]
} 'user
assert binary? inline-copy-ir [
	"inline aggregate assignment failed: " mold frontend/last-error
]
inline-copy-layout: layout-of inline-copy-ir
inline-copy-ops: ops-of inline-copy-ir inline-copy-layout
assert all [
	(function-word inline-copy-ir inline-copy-layout 1 28) = 2
	not none? find inline-copy-ops [3 4 6 3 4 6 4 5]
]["inline aggregate assignment did not use ordinary ADDRESS/MEMBER/LOAD/SET semantics"]

aggregate-call-ir: compile-text {
	Red/System []
	pair!: alias struct! [left [integer!] right [integer!]]
	copy-value: func [
		input [pair! value]
		return: [pair! value]
	][return input]
	forward: func [input [pair!] return: [pair! value]][copy-value input]
} 'user
assert binary? aggregate-call-ir [
	"aggregate call/return lowering failed: " mold frontend/last-error
]
aggregate-call-layout: layout-of aggregate-call-ir
assert all [
	(function-word aggregate-call-ir aggregate-call-layout 1 12) = 4
	(function-word aggregate-call-ir aggregate-call-layout 2 12) = 4
	(word-at aggregate-call-ir (aggregate-call-layout/5 + 4)) = 1
	(word-at aggregate-call-ir (aggregate-call-layout/5 + 12)) = 0
	(ops-of aggregate-call-ir aggregate-call-layout) = [3 4 11 3 4 7 11]
	(instruction-word aggregate-call-ir aggregate-call-layout 3 8) = 0
	(instruction-word aggregate-call-ir aggregate-call-layout 6 8) = 1
	(instruction-word aggregate-call-ir aggregate-call-layout 7 8) = 0
]["aggregate VALUE escaped its signature into runtime stack flags"]

assert none? compile-text {
	Red/System []
	left!: alias struct! [value [integer!]]
	right!: alias struct! [value [integer!]]
	box!: alias struct! [target [left! value] source [right! value]]
	fn: func [/local box [box!]][
		box: declare box!
		box/target: box/source
	]
} 'user "inline aggregate assignment accepted a different nominal type"
assert frontend/last-error/code = frontend/ERROR-REFERENCE
	"incompatible inline aggregate assignment reported the wrong error class"

global-declare-ir: compile-text {
	Red/System []
	pair-value: declare struct! [left [integer!] right [integer!]]
	fn: func [return: [integer!]][pair-value/left]
} 'user
assert binary? global-declare-ir [
	"global aggregate DECLARE failed: " mold frontend/last-error
]
global-declare-layout: layout-of global-declare-ir
assert all [
	(word-at global-declare-ir 8) = 1
	(word-at global-declare-ir 24) = 2
	(global-word global-declare-ir global-declare-layout 1 4) = 10
	(global-word global-declare-ir global-declare-layout 1 12) = 0
	(global-word global-declare-ir global-declare-layout 1 16) = 0
	(global-word global-declare-ir global-declare-layout 1 20) = 1
	(global-word global-declare-ir global-declare-layout 2 4) = 0
	(global-word global-declare-ir global-declare-layout 2 8)
		= global-word global-declare-ir global-declare-layout 1 8
	(global-word global-declare-ir global-declare-layout 2 12) = 1
	(global-word global-declare-ir global-declare-layout 2 20) = 0
	(initializer-word global-declare-ir global-declare-layout 1 0) = 2
	(initializer-word global-declare-ir global-declare-layout 1 4) = 2
	(initializer-word global-declare-ir global-declare-layout 1 8) = 2
]["global DECLARE was not one static reference to one anonymous inline object"]

array-ir: compile-text {
	Red/System []
	values: [10 20 30]
	bytes: #{090807}
	mixed: [#"A" 2 true]
	fn: func [return: [integer!] /local p [byte-ptr!]][
		values/2: 25
		p: #{030405}
		(size? values) + values/2 + bytes/1 + p/3
	]
} 'user
assert binary? array-ir ["literal arrays failed: " mold frontend/last-error]
array-layout: layout-of array-ir
values-ref: global-word array-ir array-layout 1 8
bytes-ref: global-word array-ir array-layout 2 8
mixed-ref: global-word array-ir array-layout 3 8
assert all [
	(word-at array-ir 24) = 4
	(type-word array-ir array-layout values-ref 0) = -7
	(type-word array-ir array-layout values-ref 4) = -5
	(type-word array-ir array-layout values-ref 8) = 4
	(type-word array-ir array-layout values-ref 16) = 3
	(global-word array-ir array-layout 1 12) = 1
	(global-word array-ir array-layout 1 16) = 0
	(global-word array-ir array-layout 1 20) = 3
	(initializer-word array-ir array-layout 1 0) = 1
	(initializer-word array-ir array-layout 1 4) = 10
	(initializer-word array-ir array-layout 2 4) = 20
	(initializer-word array-ir array-layout 3 4) = 30
]["integer literal array did not lower to one typed inline object"]
assert all [
	(type-word array-ir array-layout bytes-ref 0) = -7
	(type-word array-ir array-layout bytes-ref 4) = -15
	(type-word array-ir array-layout bytes-ref 8) = 1
	(type-word array-ir array-layout bytes-ref 16) = 3
	(global-word array-ir array-layout 2 12) = 1
	(global-word array-ir array-layout 2 16) = 3
	(global-word array-ir array-layout 2 20) = 1
	(initializer-word array-ir array-layout 4 0) = 3
	(initializer-word array-ir array-layout 4 4) = 0
	(initializer-word array-ir array-layout 4 8) = 3
]["binary literal did not use the compact byte initializer"]
assert all [
	(type-word array-ir array-layout mixed-ref 0) = -7
	(type-word array-ir array-layout mixed-ref 4) = -5
	(type-word array-ir array-layout mixed-ref 8) = 4
	(type-word array-ir array-layout mixed-ref 16) = 3
	(initializer-word array-ir array-layout 5 4) = 65
	(initializer-word array-ir array-layout 6 4) = 2
	(initializer-word array-ir array-layout 7 4) = 1
	not none? find ops-of array-ir array-layout 9
	not none? find ops-of array-ir array-layout 21
]["mixed scalar array or array SIZE?/INDEX semantics were lost"]
assert all [
	(global-word array-ir array-layout 4 4) = 0
	(global-word array-ir array-layout 4 8) = bytes-ref
	(global-word array-ir array-layout 4 12) = 1
	(global-word array-ir array-layout 4 16) = 7
	(global-word array-ir array-layout 4 20) = 1
	(initializer-word array-ir array-layout 8 0) = 3
	(initializer-word array-ir array-layout 8 4) = 3
	(initializer-word array-ir array-layout 8 8) = 3
]["function-local binary did not reuse one hidden static array object"]

assert none? compile-text {
	Red/System []
	values: [1 2]
	values: [3 4]
	fn: func [][]
} 'user "a literal array pointer was reassigned"
assert frontend/last-error/code = frontend/ERROR-REFERENCE
	"literal array reassignment reported the wrong error class"

assert none? compile-text {
	Red/System []
	receive: func [values [int-ptr!]][]
	fn: func [][receive [1 2]]
} 'user "a literal array was passed directly as an argument"
assert frontend/last-error/code = frontend/ERROR-UNSUPPORTED
	"direct literal array argument reported the wrong error class"

symbolic-ir: compile-text {
	Red/System []
	label: "Red"
	labels: ["alpha" "beta"]
	double: func [value [integer!] return: [integer!]][value * 2]
	triple: func [value [integer!] return: [integer!]][value * 3]
	functions: [:double :triple]
	entry: :double
	function-address: func [return: [pointer!]][as pointer! :triple]
} 'user
assert binary? symbolic-ir [
	"symbolic static initializers failed: " mold frontend/last-error
]
symbolic-layout: layout-of symbolic-ir
labels-ref: global-word symbolic-ir symbolic-layout 2 8
functions-ref: global-word symbolic-ir symbolic-layout 3 8
functions-element-ref: type-word symbolic-ir symbolic-layout functions-ref 4
assert all [
	(word-at symbolic-ir 24) = 7
	(global-word symbolic-ir symbolic-layout 1 8) = -13
	(global-word symbolic-ir symbolic-layout 1 12) = 0
	(global-word symbolic-ir symbolic-layout 1 16) = 0
	(global-word symbolic-ir symbolic-layout 1 20) = 1
	(initializer-word symbolic-ir symbolic-layout 1 0) = 2
	(initializer-word symbolic-ir symbolic-layout 1 4) = 2
	(initializer-word symbolic-ir symbolic-layout 1 8) = 5
	(global-word symbolic-ir symbolic-layout 5 12) = 1
	(initializer-word symbolic-ir symbolic-layout 7 0) = 3
]["a static string was not one pointer plus one hidden byte object"]
assert all [
	(type-word symbolic-ir symbolic-layout labels-ref 0) = -7
	(type-word symbolic-ir symbolic-layout labels-ref 4) = -13
	(type-word symbolic-ir symbolic-layout labels-ref 8) = 8
	(type-word symbolic-ir symbolic-layout labels-ref 16) = 2
	(global-word symbolic-ir symbolic-layout 2 16) = 1
	(global-word symbolic-ir symbolic-layout 2 20) = 2
	(initializer-word symbolic-ir symbolic-layout 2 0) = 2
	(initializer-word symbolic-ir symbolic-layout 2 4) = 2
	(initializer-word symbolic-ir symbolic-layout 2 8) = 6
	(initializer-word symbolic-ir symbolic-layout 3 8) = 7
]["a string array did not lower to global-address slots"]
assert all [
	(type-word symbolic-ir symbolic-layout functions-ref 0) = -7
	(type-word symbolic-ir symbolic-layout functions-element-ref 0) = -4
	(type-word symbolic-ir symbolic-layout functions-element-ref 4) = -5
	(type-word symbolic-ir symbolic-layout functions-ref 8) = 8
	(type-word symbolic-ir symbolic-layout functions-ref 16) = 2
	(global-word symbolic-ir symbolic-layout 3 16) = 3
	(global-word symbolic-ir symbolic-layout 3 20) = 2
	(initializer-word symbolic-ir symbolic-layout 4 0) = 2
	(initializer-word symbolic-ir symbolic-layout 4 4) = 4
	(initializer-word symbolic-ir symbolic-layout 4 8) = 1
	(initializer-word symbolic-ir symbolic-layout 5 8) = 2
	(global-word symbolic-ir symbolic-layout 4 8) = functions-element-ref
	(initializer-word symbolic-ir symbolic-layout 6 4) = 4
	(initializer-word symbolic-ir symbolic-layout 6 8) = 1
]["function addresses did not use the ordinary address initializer"]
symbolic-ops: ops-of symbolic-ir symbolic-layout
assert not none? find symbolic-ops [3 20 8 11]
	"runtime function address did not use ADDRESS/REFERENCE/CAST"

function-value-ir: compile-text {
	Red/System []
	op!: alias function! [value [integer!] return: [integer!]]
	box!: alias struct! [apply [op!]]
	inc: func [value [integer!] return: [integer!]][value + 1]
	functions: [:inc]
	run: func [return: [integer!] /local fn [op!] holder [box!]][
		holder: declare box!
		holder/apply: as op! :inc
		fn: as op! functions/1
		if :fn = null [return 0]
		if (fn 41) <> 42 [return 0]
		holder/apply 40
	]
} 'user
assert binary? function-value-ir [
	"typed function values failed: " mold frontend/last-error
]
function-value-layout: layout-of function-value-ir
function-type: 0
function-call: 0
repeat id word-at function-value-ir 8 [
	if (type-word function-value-ir function-value-layout id 0) = -4 [
		function-type: id
	]
]
repeat id word-at function-value-ir 20 [
	if all [
		(instruction-word function-value-ir function-value-layout id 0) = 7
		(instruction-word function-value-ir function-value-layout id 4) = 0
	][function-call: id]
]
assert all [
	function-type > 0
	function-call > 0
	(instruction-word function-value-ir function-value-layout function-call 12)
		= function-type
	not none? find ops-of function-value-ir function-value-layout 6
	not none? find ops-of function-value-ir function-value-layout 20
	]
	"function values did not lower to typed ADDRESS/REFERENCE/LOAD/CALL"

function-global-ir: compile-text {
	Red/System []
	op!: alias function! [value [integer!] return: [integer!]]
	inc: func [value [integer!] return: [integer!]][value + 1]
	op-global: as op! :inc
	run: func [return: [integer!]][op-global 41]
} 'user
assert binary? function-global-ir [
	"global function value failed: " mold frontend/last-error
]
function-global-layout: layout-of function-global-ir
assert all [
	(word-at function-global-ir 24) = 1
	(global-word function-global-ir function-global-layout 1 20) = 1
	(initializer-word function-global-ir function-global-layout 1 0) = 2
	(initializer-word function-global-ir function-global-layout 1 4) = 4
	(initializer-word function-global-ir function-global-layout 1 8) = 1
	not none? find ops-of function-global-ir function-global-layout 7
]["global function value was not one typed static relocation and indirect CALL"]

assert binary? compile-text {
	Red/System []
	op!: alias function! [value [integer!] return: [integer!]]
	nullable: func [return: [logic!] /local fn [op!]][
		fn: null
		:fn = null
	]
} 'user "implicit null function assignment was rejected"

assert binary? compile-text {
	Red/System []
	inc: func [value [integer!] return: [integer!]][value + 1]
	address: func [return: [integer!]][as integer! :inc]
} 'user "function-to-integer cast was rejected"

assert none? compile-text {
	Red/System []
	inc: func [value [integer!] return: [integer!]][value + 1]
	bad: func [return: [byte!]][as byte! :inc]
} 'user "function-to-byte cast was accepted"
assert frontend/last-error/code = frontend/ERROR-REFERENCE
	"invalid function cast reported the wrong error class"

callback-ir: compile-text {
	Red/System []
	#import [
		"foo.dll" cdecl [
			foo: "foo" [
				fun [function! [a [integer!] b [integer!] return: [logic!]]]
				return: [integer!]
			]
		]
	]
	compare: func [[cdecl] left [integer!] right [integer!] return: [logic!]][
		left <= right
	]
	run: func [return: [integer!]][foo :compare]
} 'user
assert binary? callback-ir [
	"callback function signature was rejected: " mold frontend/last-error
]
callback-call: 0
repeat id word-at callback-ir 20 [
	if all [
		(instruction-word callback-ir (layout-of callback-ir) id 0) = 7
		(instruction-word callback-ir (layout-of callback-ir) id 4) < 0
	][callback-call: id]
]
assert callback-call > 0 "callback did not lower through an imported CALL"

assert none? compile-text {
	Red/System []
	#import [
		"foo.dll" cdecl [
			foo: "foo" [
				fun [function! [a [integer!] b [integer!] return: [logic!]]]
				return: [integer!]
			]
		]
	]
	compare: func [[cdecl] left [integer!] return: [logic!]][left <> 0]
	run: func [][foo :compare]
} 'user "a callback signature mismatch was accepted"
assert frontend/last-error/code = frontend/ERROR-REFERENCE
	"function signature mismatch reported the wrong error class"

assert binary? compile-text {
	Red/System []
	op!: alias function! [value [integer!] return: [integer!]]
	wrong: func [value [byte!] return: [integer!]][value]
	bad: func [return: [integer!] /local fn [op!]][
		fn: as op! :wrong
		fn 4
	]
} 'user "explicit function-to-function cast was rejected"

assert none? compile-text {
	Red/System []
	op!: alias function! [value [integer!] return: [integer!]]
	bad: func [return: [integer!]][as op! null]
} 'user "explicit null function cast was accepted"
assert frontend/last-error/code = frontend/ERROR-REFERENCE
	"explicit null function cast reported the wrong error class"

protect-ir: compile-text {
	Red/System []
	nums: protect [10 20 30]
	truth: protect true
	msg: protect "Red"
	bin: protect #{C0FFEE}
	cast: protect as byte-ptr! "AB"
	typed: protect as int32! 7
	RATE: protect 60
	HALF: protect 0.5
	LETTER: protect #"Z"
	table: [1 RATE 3]
	read-rate: func [return: [integer!]][RATE + nums/2]
	read-half: func [return: [float!]][HALF]
	read-letter: func [return: [byte!]][LETTER]
	read-truth: func [return: [logic!]][truth]
} 'user
assert binary? protect-ir ["PROTECT lowering failed: " mold frontend/last-error]
protect-layout: layout-of protect-ir
assert all [
	(word-at protect-ir 24) = 9
	(global-word protect-ir protect-layout 1 12) = 3
	(global-word protect-ir protect-layout 1 16) = 0
	(global-word protect-ir protect-layout 1 20) = 3
	(global-word protect-ir protect-layout 2 8) = -11
	(global-word protect-ir protect-layout 2 12) = 2
	(global-word protect-ir protect-layout 2 16) = 3
	(global-word protect-ir protect-layout 2 20) = 1
	(global-word protect-ir protect-layout 3 8) = -13
	(global-word protect-ir protect-layout 3 12) = 2
	(global-word protect-ir protect-layout 4 12) = 3
	(global-word protect-ir protect-layout 5 12) = 2
	(global-word protect-ir protect-layout 6 12) = 2
	(global-word protect-ir protect-layout 7 12) = 1
	(global-word protect-ir protect-layout 8 12) = 3
	(global-word protect-ir protect-layout 9 12) = 3
]["PROTECT did not preserve the scalar/reference storage distinction"]
assert all [
	(initializer-word protect-ir protect-layout 4 0) = 1
	(initializer-word protect-ir protect-layout 4 4) = 1
	(initializer-word protect-ir protect-layout 5 0) = 2
	(initializer-word protect-ir protect-layout 5 4) = 2
	(initializer-word protect-ir protect-layout 5 8) = 8
	(initializer-word protect-ir protect-layout 7 0) = 2
	(initializer-word protect-ir protect-layout 7 4) = 2
	(initializer-word protect-ir protect-layout 7 8) = 9
	(initializer-word protect-ir protect-layout 8 0) = 1
	(initializer-word protect-ir protect-layout 8 4) = 7
	(initializer-word protect-ir protect-layout 10 4) = 60
]["protected values did not use the ordinary flat initializer stream"]
protect-literals: make block! 32
repeat id word-at protect-ir 20 [
	if (instruction-word protect-ir protect-layout id 0) = 1 [
		repend protect-literals [
			instruction-word protect-ir protect-layout id 4
			instruction-word protect-ir protect-layout id 8
			instruction-word protect-ir protect-layout id 12
		]
	]
]
assert all [
	not none? find protect-literals [-5 60 0]
	not none? find protect-literals [-10 0 1071644672]
	not none? find protect-literals [-15 90 0]
]["protected scalar constants were not folded to ordinary typed literals"]

assert none? compile-text {
	Red/System [] RATE: protect 60 RATE: 61 fn: func [][]
} 'user "a protected scalar was reassigned"
assert frontend/last-error/code = frontend/ERROR-REFERENCE
	"protected scalar reassignment reported the wrong error class"

assert none? compile-text {
	Red/System [] values: protect [1 2] values/1: 0 fn: func [][]
} 'user "a protected path was written directly"
assert frontend/last-error/code = frontend/ERROR-REFERENCE
	"protected path write reported the wrong error class"

assert binary? compile-text {
	Red/System []
	values: protect [1 2]
	shadow: func [return: [integer!] /local values][values: 3 values: values + 1 values]
	derived-write: func [/local p [int-ptr!]][p: values p/1: 0]
} 'user ["local shadow or derived pointer lost ordinary value semantics: " mold frontend/last-error]

assert none? compile-text {
	Red/System []
	ns: context [values: protect [1 2]]
	ns/values/1: 0
	fn: func [][]
} 'user "a namespace-qualified protected path was written"
assert frontend/last-error/code = frontend/ERROR-REFERENCE
	"qualified protected path write reported the wrong error class"

assert none? compile-text {
	Red/System [] value: protect (1 + 2) fn: func [][]
} 'user "PROTECT accepted a computed expression"
assert frontend/last-error/code = frontend/ERROR-UNSUPPORTED
	"nonliteral PROTECT value reported the wrong error class"

assert none? compile-text {
	Red/System [] fn: func [][value: protect 1]
} 'user "PROTECT was accepted inside a function"
assert frontend/last-error/code = frontend/ERROR-CONTEXT
	"local PROTECT reported the wrong error class"

assert none? compile-text {
	Red/System []
	empty!: alias struct! []
	fn: func [return: [integer!]][0]
} 'user "empty aggregate alias was accepted"
assert frontend/last-error/code = frontend/ERROR-UNSUPPORTED
	"empty aggregate alias reported the wrong error class"

assert none? compile-text {
	Red/System []
	fn: func [p [int-ptr!] index [logic!] return: [integer!]][p/index]
} 'user "pointer indexing accepted a non-integer! index"
assert frontend/last-error/code = frontend/ERROR-REFERENCE
	"invalid pointer index reported the wrong error class"

variadic-ir: compile-text {
	Red/System []
	collect: func [
		[variadic]
		count [integer!]
		list [int-ptr!]
		size [integer!]
		return: [integer!]
	][count]
	main: func [return: [integer!]][collect [11 22 33]]
} 'user
assert binary? variadic-ir [
	"native variadic call failed: " mold frontend/last-error
]
variadic-layout: layout-of variadic-ir
assert all [
	(function-word variadic-ir variadic-layout 1 12) = 8
	(function-word variadic-ir variadic-layout 1 20) = 3
	(ops-of variadic-ir variadic-layout) = [3 4 11 1 1 1 7 11]
	(instruction-word variadic-ir variadic-layout 7 4) = 1
	(instruction-word variadic-ir variadic-layout 7 8) = 3
	(instruction-word variadic-ir variadic-layout 7 12) = -5
]["native variadic arguments did not remain one source-order CALL payload"]

assert binary? compile-text {
	Red/System []
	collect: func [
		[variadic]
		count [integer!]
		list [int-ptr!]
		return: [integer!]
	][count]
	main: func [return: [integer!]][collect []]
} 'user "native variadic count/list signature or empty argument block was rejected"

import-variadic-ir: compile-text {
	Red/System []
	#import [
		"foo.dll" stdcall [
			sink: "sink" [[variadic] return: [integer!]]
		]
	]
	main: func [return: [integer!]][sink [11 22]]
} 'user
assert binary? import-variadic-ir [
	"imported native variadic call failed: " mold frontend/last-error
]
import-variadic-layout: layout-of import-variadic-ir
import-variadic-call: 0
repeat id word-at import-variadic-ir 20 [
	if (instruction-word import-variadic-ir import-variadic-layout id 0) = 7 [
		import-variadic-call: id
	]
]
assert all [
	(word-at import-variadic-ir (import-variadic-layout/2 + 20)) = 10
	import-variadic-call > 0
	(instruction-word import-variadic-ir import-variadic-layout
		import-variadic-call 4) < 0
	(instruction-word import-variadic-ir import-variadic-layout
		import-variadic-call 8) = 2
]["imported variadic calls did not use the implicit packed ABI"]

assert none? compile-text {
	Red/System []
	#import [
		"foo.dll" stdcall [
			bad: "bad" [[variadic] count [integer!] list [int-ptr!]]
		]
	]
	main: func [return: [integer!]][bad [1]]
} 'user "imported variadic declaration incorrectly accepted native parameters"
assert frontend/last-error/code = frontend/ERROR-UNSUPPORTED
	"invalid imported variadic declaration reported the wrong error class"

cdecl-variadic-ir: compile-text {
	Red/System []
	sink: func [
		[cdecl variadic]
		fixed [integer!]
		return: [integer!]
	][fixed]
	main: func [return: [integer!]][sink [1 as float32! 2.0]]
} 'user
assert binary? cdecl-variadic-ir [
	"cdecl variadic call failed: " mold frontend/last-error
]
cdecl-variadic-layout: layout-of cdecl-variadic-ir
cdecl-variadic-call: 0
cdecl-variadic-promotion: 0
repeat id word-at cdecl-variadic-ir 20 [
	either (instruction-word cdecl-variadic-ir cdecl-variadic-layout id 0) = 7 [
		cdecl-variadic-call: id
	][
		if all [
			(instruction-word cdecl-variadic-ir cdecl-variadic-layout id 0) = 8
			(instruction-word cdecl-variadic-ir cdecl-variadic-layout id 4) = -10
		][cdecl-variadic-promotion: id]
	]
]
assert all [
	(function-word cdecl-variadic-ir cdecl-variadic-layout 1 12) = 9
	cdecl-variadic-call > 0
	cdecl-variadic-promotion > 0
	(instruction-word cdecl-variadic-ir cdecl-variadic-layout
		cdecl-variadic-call 8) = 2
]["cdecl variadic prefix checking or float promotion is incorrect"]

indirect-variadic-ir: compile-text {
	Red/System []
	variadic-op!: alias function! [
		[variadic]
		count [integer!]
		list [int-ptr!]
		size [integer!]
		return: [integer!]
	]
	collect: func [
		[variadic]
		count [integer!]
		list [int-ptr!]
		size [integer!]
		return: [integer!]
	][count]
	main: func [return: [integer!] /local fn [variadic-op!]][
		fn: as variadic-op! :collect
		fn [4 5]
	]
} 'user
assert binary? indirect-variadic-ir [
	"indirect native variadic call failed: " mold frontend/last-error
]
indirect-variadic-layout: layout-of indirect-variadic-ir
indirect-variadic-call: 0
repeat id word-at indirect-variadic-ir 20 [
	if all [
		(instruction-word indirect-variadic-ir indirect-variadic-layout id 0) = 7
		(instruction-word indirect-variadic-ir indirect-variadic-layout id 4) = 0
	][indirect-variadic-call: id]
]
assert all [
	indirect-variadic-call > 0
	(instruction-word indirect-variadic-ir indirect-variadic-layout
		indirect-variadic-call 8) = 2
	(instruction-word indirect-variadic-ir indirect-variadic-layout
		indirect-variadic-call 12) > 0
]["indirect variadic CALL lost its function signature or source argument count"]

assert none? compile-text {
	Red/System []
	bad: func [[variadic] value [integer!] return: [integer!]][value]
	main: func [return: [integer!]][bad [1]]
} 'user "native variadic call accepted a non-variadic callee signature"
assert frontend/last-error/code = frontend/ERROR-UNSUPPORTED
	"invalid native variadic signature reported the wrong error class"

assert none? compile-text {
	Red/System []
	collect: func [
		[variadic]
		count [integer!]
		list [int-ptr!]
		return: [integer!]
	][count]
	main: func [return: [integer!]][collect 1]
} 'user "native variadic call accepted a non-block argument"
assert frontend/last-error/code = frontend/ERROR-UNSUPPORTED
	"non-block variadic call reported the wrong error class"

typed-ir: compile-text {
	Red/System []
	typed-value!: alias struct! [
		type [integer!]
		_align0 [integer!]
		value [int-ptr!]
		_padding [integer!]
		_align1 [integer!]
	]
	sample!: alias struct! [value [integer!]]
	sink: func [
		[typed]
		count [integer!]
		list [typed-value!]
		return: [integer!]
	][count]
	main: func [return: [integer!] /local item [sample!]][
		item: declare sample!
		sink [
			#"A"
			as uint8! 250
			as int8! -2
			-123456
			as float32! 1.5
			2.0
			"text"
			as int64! -3
			as uint64! FFFFFFFFh
			item
		]
	]
} 'user
assert binary? typed-ir ["typed call failed: " mold frontend/last-error]
typed-layout: layout-of typed-ir
typed-call: 0
repeat id word-at typed-ir 20 [
	if (instruction-word typed-ir typed-layout id 0) = 7 [typed-call: id]
]
typed-metadata: instruction-word typed-ir typed-layout typed-call 12
typed-first: 1 + type-word typed-ir typed-layout typed-metadata 12
typed-arguments: copy []
repeat id type-word typed-ir typed-layout typed-metadata 16 [
	repend typed-arguments [
		member-word typed-ir typed-layout (typed-first + id - 1) 0
		member-word typed-ir typed-layout (typed-first + id - 1) 4
	]
]
assert all [
	typed-call > 0
	(instruction-word typed-ir typed-layout typed-call 8) = 10
	(type-word typed-ir typed-layout typed-metadata 0) = -8
	(type-word typed-ir typed-layout typed-metadata 16) = 10
	(type-word typed-ir typed-layout
		(type-word typed-ir typed-layout typed-metadata 4) 0) = -4
	typed-arguments = [
		-15 3 -2 14 -1 13 -5 2 -9 4 -10 5 -13 6 -7 11 -8 12 2 1002
	]
]["typed call metadata lost source types or runtime type IDs: " mold typed-arguments]

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

infix-ir: compile-text {
	Red/System []
	avg: func ["Average two values" [infix] a [integer!] b [integer!] return: [integer!]][
		a + b
	]
	main: func [return: [integer!]][10 avg 6 + 2]
} 'user
assert binary? infix-ir ["infix function failed: " mold frontend/last-error]
infix-layout: layout-of infix-ir
assert all [
	(word-at infix-ir 16) = 2
	(function-word infix-ir infix-layout 1 12) = 0
	(ops-of infix-ir infix-layout) = [3 4 3 4 15 11 1 1 7 1 15 11]
	(instruction-word infix-ir infix-layout 9 4) = 1
	(instruction-word infix-ir infix-layout 9 8) = 2
	(instruction-word infix-ir infix-layout 9 12) = -5
	(word-at infix-ir 0) = 1
]["infix syntax did not lower to an ordinary two-argument call"]

infix-prefix-ir: compile-text {
	Red/System []
	avg: func [[infix] a [integer!] b [integer!] return: [integer!]][a + b]
	main: func [return: [integer!]][avg 10 6]
} 'user
assert binary? infix-prefix-ir [
	"infix prefix form failed: " mold frontend/last-error
]
assert (ops-of infix-prefix-ir layout-of infix-prefix-ir) = [
	3 4 3 4 15 11 1 1 7 11
]["infix prefix form was not retained when no left operand existed"]

import-infix-ir: compile-text {
	Red/System []
	#import [
		"foo.dll" cdecl [
			combine: "combine" [[infix] a [integer!] b [integer!] return: [integer!]]
		]
	]
	main: func [return: [integer!]][10 combine 6]
} 'user
assert binary? import-infix-ir [
	"imported infix function failed: " mold frontend/last-error
]
import-infix-layout: layout-of import-infix-ir
assert all [
	(word-at import-infix-ir (import-infix-layout/2 + 20)) = 1
	(ops-of import-infix-ir import-infix-layout) = [1 1 7 11]
	(instruction-word import-infix-ir import-infix-layout 3 4) = -1
	(instruction-word import-infix-ir import-infix-layout 3 8) = 2
]["imported infix syntax did not retain the ordinary import CALL shape"]

infix-shadow-ir: compile-text {
	Red/System []
	choose: func [[infix] a [integer!] b [integer!] return: [integer!]][a + b]
	ns: context [
		choose: func [value [integer!] return: [integer!]][value]
		main: func [return: [integer!]][1 choose 2]
	]
} 'user
assert binary? infix-shadow-ir [
	"ordinary function failed to shadow infix function: " mold frontend/last-error
]
infix-shadow-layout: layout-of infix-shadow-ir
infix-shadow-call: 0
repeat id word-at infix-shadow-ir 20 [
	if (instruction-word infix-shadow-ir infix-shadow-layout id 0) = 7 [
		infix-shadow-call: id
	]
]
assert all [
	infix-shadow-call > 0
	(instruction-word infix-shadow-ir infix-shadow-layout infix-shadow-call 4) = 2
	(instruction-word infix-shadow-ir infix-shadow-layout infix-shadow-call 8) = 1
]["infix lookup bypassed lexical shadowing"]

assert none? compile-text {
	Red/System [] bad: func [[infix] a [integer!]][a]
} 'user "infix accepted a one-argument function"
assert frontend/last-error/code = frontend/ERROR-ARGUMENTS
	"infix arity failure reported the wrong error class"

assert none? compile-text {
	Red/System [] bad: func [[infix] a [integer!] b [integer!] c [integer!]][a]
} 'user "infix accepted a three-argument function"
assert frontend/last-error/code = frontend/ERROR-ARGUMENTS
	"infix three-argument failure reported the wrong error class"

assert none? compile-text {
	Red/System []
	ns: context [
		add: func [[infix] a [integer!] b [integer!] return: [integer!]][a + b]
	]
	main: func [return: [integer!]][1 ns/add 2]
} 'user "infix accepted path call syntax"
assert frontend/last-error/code = frontend/ERROR-UNSUPPORTED
	"infix path call failure reported the wrong error class"

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
	letter: #"B"
	fn: func [return: [byte!]][#"A"]
} 'user
byte-layout: layout-of byte-ir
assert all [
	(global-word byte-ir byte-layout 1 8) = -15
	(function-word byte-ir byte-layout 1 8) = -15
	(instruction-word byte-ir byte-layout 1 4) = -15
	(instruction-word byte-ir byte-layout 1 8) = 65
]["byte literal did not retain its logical byte type"]

if-ir: compile-text {
	Red/System []
	fn: func [flag [logic!] return: [integer!] /local value][
		value: 0
		if flag [value: 7]
		value
	]
} 'user
assert binary? if-ir ["IF lowering failed: " mold frontend/last-error]
if-layout: layout-of if-ir
assert all [
	(ops-of if-ir if-layout) = [3 1 5 12 3 4 17 3 1 5 12 3 4 11]
	(instruction-word if-ir if-layout 7 4) = 12
	(instruction-word if-ir if-layout 7 8) = 0
]["IF did not lower to a false branch over an ordinary body"]

either-ir: compile-text {
	Red/System []
	fn: func [flag [logic!] return: [integer!]][either flag [11][22]]
} 'user
assert binary? either-ir ["EITHER lowering failed: " mold frontend/last-error]
either-layout: layout-of either-ir
assert all [
	(function-word either-ir either-layout 1 28) = 0
	(ops-of either-ir either-layout) = [3 4 17 1 16 1 11]
	(instruction-word either-ir either-layout 3 4) = 6
	(instruction-word either-ir either-layout 5 4) = 7
	(instruction-word either-ir either-layout 5 8) = 0
]["value-returning EITHER did not merge at one typed stack depth"]

either-statement-ir: compile-text {
	Red/System []
	fn: func [flag [logic!]][either flag [1][true]]
} 'user
either-statement-layout: layout-of either-statement-ir
assert all [
	(function-word either-statement-ir either-statement-layout 1 28) = 0
	(ops-of either-statement-ir either-statement-layout) = [3 4 17 1 16 1 12 11]
	(instruction-word either-statement-ir either-statement-layout 5 8) = 1
]["statement EITHER did not reconcile different arm values on its edges"]

case-ir: compile-text {
	Red/System []
	choose: func [value [integer!] return: [integer!]][
		case [
			value = 1 [11]
			value = 2 [22]
			true [33]
		]
	]
} 'user
assert binary? case-ir ["CASE lowering failed: " mold frontend/last-error]
case-layout: layout-of case-ir
assert all [
	(word-at case-ir 28) = 0
	(ops-of case-ir case-layout) = [
		3 4 1 15 17 1 16
		3 4 1 15 17 1 16
		1 17 1 16 19 11
	]
	(instruction-word case-ir case-layout 5 4) = 8
	(instruction-word case-ir case-layout 12 4) = 15
	(instruction-word case-ir case-layout 16 4) = 19
	(instruction-word case-ir case-layout 19 4) = 100
]["CASE did not lower through generic branches and a non-returning failure"]

switch-ir: compile-text {
	Red/System []
	choose: func [value [integer!] return: [integer!]][
		switch value [1 2 [11] 3 [22] default [33]]
	]
} 'user
assert binary? switch-ir ["SWITCH lowering failed: " mold frontend/last-error]
switch-layout: layout-of switch-ir
assert all [
	(word-at switch-ir 28) = 3
	(ops-of switch-ir switch-layout) = [3 4 18 1 16 1 16 1 11]
	(instruction-word switch-ir switch-layout 3 4) = 0
	(instruction-word switch-ir switch-layout 3 8) = 3
	(instruction-word switch-ir switch-layout 3 12) = 8
	(switch-word switch-ir switch-layout 1 0) = 1
	(switch-word switch-ir switch-layout 1 8) = 4
	(switch-word switch-ir switch-layout 2 0) = 2
	(switch-word switch-ir switch-layout 2 8) = 4
	(switch-word switch-ir switch-layout 3 0) = 3
	(switch-word switch-ir switch-layout 3 8) = 6
]["SWITCH did not preserve its compact literal/target slice"]

switch-miss-ir: compile-text {
	Red/System []
	choose: func [value [integer!] return: [integer!] /local result [integer!]][
		result: 7
		switch value [1 [result: 9]]
		result
	]
} 'user
assert binary? switch-miss-ir [
	"SWITCH missing-case continuation failed: " mold frontend/last-error
]
switch-miss-layout: layout-of switch-miss-ir
switch-miss-ops: ops-of switch-miss-ir switch-miss-layout
assert all [
	none? find switch-miss-ops 19
	not none? find switch-miss-ops 16
]["statement SWITCH without DEFAULT did not preserve its no-match continuation"]

tagged-ir: compile-text {
	Red/System []
	event!: alias union! [
		[variant]
		mouse [x [integer!] y [integer!]]
		key [integer!]
	]
	inspect: func [return: [integer!] /local event [event!] score [integer!]][
		event: declare event!
		event/mouse/x: 10
		score: either variant? event 'mouse [1][0]
		switch event [
			mouse [score: score + 2]
			key [score: score + 4]
		]
		score
	]
} 'user
assert binary? tagged-ir ["tagged union lowering failed: " mold frontend/last-error]
tagged-layout: layout-of tagged-ir
tagged-ops: ops-of tagged-ir tagged-layout
tagged-member-at: 32 + ((word-at tagged-ir 8) * 20)
tagged-write?: false
repeat id word-at tagged-ir 20 [
	if all [
		(instruction-word tagged-ir tagged-layout id 0) = 6
		(instruction-word tagged-ir tagged-layout id 8) = 1
	][tagged-write?: true]
]
assert all [
	(word-at tagged-ir 8) = 2
	(word-at tagged-ir 32) = -3
	(word-at tagged-ir 40) = 1
	(word-at tagged-ir 48) = 2
	(word-at tagged-ir tagged-member-at) = 2
	(word-at tagged-ir (tagged-member-at + 4)) = 1
	(word-at tagged-ir (tagged-member-at + 8)) = -5
	(word-at tagged-ir (tagged-member-at + 12)) = 0
	tagged-write?
	not none? find tagged-ops 22
	(switch-word tagged-ir tagged-layout 1 0) = 1
	(switch-word tagged-ir tagged-layout 2 0) = 2
]["tagged union did not retain one tagged layout and ordinary member/tag operations"]

assert none? compile-text {
	Red/System []
	raw!: alias union! [value [integer!]]
	fn: func [raw [raw!] return: [logic!]][variant? raw 'value]
} 'user "VARIANT? accepted a raw union"
assert frontend/last-error/code = frontend/ERROR-REFERENCE
	"raw union VARIANT? reported the wrong error class"

wide-switch-ir: compile-text {
	Red/System []
	choose: func [return: [integer!]][
		switch #u64h-0000000100000000 [
			#u64h-0000000100000000 [7]
			default [9]
		]
	]
} 'user
assert binary? wide-switch-ir [
	"64-bit SWITCH lowering failed: " mold frontend/last-error
]
wide-switch-layout: layout-of wide-switch-ir
assert all [
	(instruction-word wide-switch-ir wide-switch-layout 1 4) = -7
	(instruction-word wide-switch-ir wide-switch-layout 1 8) = 0
	(instruction-word wide-switch-ir wide-switch-layout 1 12) = 1
	(switch-word wide-switch-ir wide-switch-layout 1 0) = 0
	(switch-word wide-switch-ir wide-switch-layout 1 4) = 1
]["64-bit literals did not retain both limbs in SWITCH"]

enum-switch-ir: compile-text {
	Red/System []
	#enum kind! [zero one two]
	choose: func [value [integer!] return: [integer!]][
		switch value [one [7] default [9]]
	]
} 'user
assert binary? enum-switch-ir ["enum SWITCH lowering failed: " mold frontend/last-error]
enum-switch-layout: layout-of enum-switch-ir
assert (switch-word enum-switch-ir enum-switch-layout 1 0) = 1
	"enum symbol was not resolved as a compile-time SWITCH literal"

widen-ir: compile-text {
	Red/System []
	widen: func [
		small [int8!]
		return: [int64!]
		/local medium [int32!]
	][
		medium: small
		medium
	]
} 'user
assert binary? widen-ir ["lossless integer widening failed: " mold frontend/last-error]
widen-layout: layout-of widen-ir
assert all [
	(ops-of widen-ir widen-layout) = [3 3 4 8 5 12 3 4 8 11]
	(instruction-word widen-ir widen-layout 4 4) = -5
	(instruction-word widen-ir widen-layout 9 4) = -7
]["lossless assignment/return widening did not use ordinary CAST operations"]

early-widen-ir: compile-text {
	Red/System []
	widen: func [value [int8!] return: [int64!]][return value]
} 'user
assert binary? early-widen-ir [
	"explicit RETURN widening failed: " mold frontend/last-error
]
early-widen-layout: layout-of early-widen-ir
assert all [
	(ops-of early-widen-ir early-widen-layout) = [3 4 8 11]
	(instruction-word early-widen-ir early-widen-layout 3 4) = -7
]["explicit RETURN did not use the ordinary lossless CAST path"]

widen-call-ir: compile-text {
	Red/System []
	take: func [value [int32!] return: [int32!]][value]
	give: func [value [uint8!] return: [int32!]][take value]
	c-id: func [[cdecl] return: [integer!]][7]
} 'user
assert binary? widen-call-ir [
	"lossless argument widening failed: " mold frontend/last-error
]
widen-call-layout: layout-of widen-call-ir
assert all [
	(ops-of widen-call-ir widen-call-layout) = [3 4 11 3 4 8 7 11 1 11]
	(instruction-word widen-call-ir widen-call-layout 6 4) = -5
	(instruction-word widen-call-ir widen-call-layout 7 4) = 1
	(function-word widen-call-ir widen-call-layout 3 12) = 1
	(instruction-word widen-call-ir widen-call-layout 10 8) = 0
]["argument widening or scalar calling-convention return flags are incorrect"]

widen-compare-ir: compile-text {
	Red/System []
	equal?: func [value [int8!] return: [logic!]][value = -7]
} 'user
assert binary? widen-compare-ir [
	"lossless comparison widening failed: " mold frontend/last-error
]
widen-compare-layout: layout-of widen-compare-ir
assert (ops-of widen-compare-ir widen-compare-layout) = [3 4 1 15 11]
	"integer comparison widening introduced a source-shaped operation"

enum-widen-ir: compile-text {
	Red/System []
	#enum kind! [zero one]
	widen: func [value [kind!] return: [int64!]][value]
} 'user
assert binary? enum-widen-ir ["enum widening failed: " mold frontend/last-error]
enum-widen-layout: layout-of enum-widen-ir
assert all [
	(ops-of enum-widen-ir enum-widen-layout) = [3 4 8 11]
	(instruction-word enum-widen-ir enum-widen-layout 3 4) = -7
]["logical integer types did not participate in generic widening"]

wide-float-ir: compile-text {
	Red/System []
	value: func [return: [float!]][1.5]
} 'user
assert binary? wide-float-ir ["float! literal failed: " mold frontend/last-error]
wide-float-layout: layout-of wide-float-ir
assert all [
	(ops-of wide-float-ir wide-float-layout) = [1 11]
	(instruction-word wide-float-ir wide-float-layout 1 4) = -10
	(instruction-word wide-float-ir wide-float-layout 1 8) = 0
	(instruction-word wide-float-ir wide-float-layout 1 12) = 1073217536
]["float! literal did not retain its IEEE binary64 payload"]

single-float-ir: compile-text {
	Red/System []
	value: func [return: [float32!]][as float32! 1.5]
} 'user
assert binary? single-float-ir ["float32! literal failed: " mold frontend/last-error]
single-float-layout: layout-of single-float-ir
assert all [
	(ops-of single-float-ir single-float-layout) = [1 11]
	(instruction-word single-float-ir single-float-layout 1 4) = -9
	(instruction-word single-float-ir single-float-layout 1 8) = 1069547520
	(instruction-word single-float-ir single-float-layout 1 12) = 0
]["float32! literal was not directly typed at compile time"]

float-expression-cast-ir: compile-text {
	Red/System []
	value: func [return: [float32!]][as float32! (1.0 + 2.0)]
} 'user
assert binary? float-expression-cast-ir [
	"floating expression cast failed: " mold frontend/last-error
]
float-expression-cast-layout: layout-of float-expression-cast-ir
assert (ops-of float-expression-cast-ir float-expression-cast-layout) = [1 1 15 8 11]
	"float constant typing changed the specified expression boundary"

float-cast-ir: compile-text {
	Red/System []
	to-wide: func [value [integer!] return: [float!]][as float! value]
	bits: func [value [float32!] return: [integer!]][as integer! keep value]
} 'user
assert binary? float-cast-ir ["scalar float casts failed: " mold frontend/last-error]
float-cast-layout: layout-of float-cast-ir
assert all [
	(ops-of float-cast-ir float-cast-layout) = [3 4 8 11 3 4 8 11]
	(instruction-word float-cast-ir float-cast-layout 3 4) = -10
	(instruction-word float-cast-ir float-cast-layout 3 12) = 0
	(instruction-word float-cast-ir float-cast-layout 7 4) = -5
	(instruction-word float-cast-ir float-cast-layout 7 12) = 1
]["numeric and bit-preserving casts did not share the ordinary CAST operation"]

float-argument-ir: compile-text {
	Red/System []
	take: func [value [float32!] return: [float32!]][value]
	give: func [return: [float32!]][take 1.5]
} 'user
assert binary? float-argument-ir [
	"implicit float32! literal argument failed: " mold frontend/last-error
]
float-argument-layout: layout-of float-argument-ir
assert all [
	(ops-of float-argument-ir float-argument-layout) = [3 4 11 1 8 7 11]
	(instruction-word float-argument-ir float-argument-layout 5 4) = -9
]["float32! argument literal coercion was not represented by CAST"]

short-ir: compile-text {
	Red/System []
	fn: func [a [logic!] b [logic!] return: [logic!]][any [a b]]
} 'user
short-layout: layout-of short-ir
assert all [
	(function-word short-ir short-layout 1 28) = 0
	(ops-of short-ir short-layout) = [
		3 4 17 3 4 16 1 11
	]
	(instruction-word short-ir short-layout 3 8) = 1
	(instruction-word short-ir short-layout 3 4) = 7
	(instruction-word short-ir short-layout 6 4) = 8
]["ANY did not merge its short-circuit result on the typed stack"]

single-all-ir: compile-text {
	Red/System []
	fn: func [value [logic!] return: [logic!]][all [value]]
} 'user
single-all-layout: layout-of single-all-ir
assert all [
	(function-word single-all-ir single-all-layout 1 28) = 0
	(ops-of single-all-ir single-all-layout) = [3 4 11]
]["a one-condition ALL retained unnecessary control or merge work"]

loops-ir: compile-text {
	Red/System []
	fn: func [return: [integer!] /local i value][
		i: 0
		value: 0
		loop 5 [
			i: i + 1
			if i = 2 [continue]
			value: value + 1
			if i = 4 [break]
		]
		while [i: i - 1 i > 0][value: value + 1]
		until [i: i + 1 i = 2]
		value
	]
} 'user
assert binary? loops-ir ["loop lowering failed: " mold frontend/last-error]
loops-layout: layout-of loops-ir
assert all [
	(function-word loops-ir loops-layout 1 28) = 3
	not none? find ops-of loops-ir loops-layout 16
	not none? find ops-of loops-ir loops-layout 17
]["structured loops did not share the generic jump/branch core"]

return-ir: compile-text {
	Red/System []
	fn: func [value [integer!] return: [integer!]][
		if value > 0 [return 7]
		9
	]
} 'user
assert binary? return-ir ["early RETURN lowering failed: " mold frontend/last-error]
return-layout: layout-of return-ir
assert (ops-of return-ir return-layout) = [3 4 1 15 17 1 11 1 11]
	"an early RETURN became a special conditional form"

exit-ir: compile-text {
	Red/System []
	fn: func [flag [logic!] /local value][
		value: 1
		if flag [exit]
		value: 2
	]
} 'user
assert binary? exit-ir ["early EXIT lowering failed: " mold frontend/last-error]
exit-layout: layout-of exit-ir
assert all [
	(ops-of exit-ir exit-layout) = [3 1 5 12 3 4 17 11 3 1 5 12 11]
	(instruction-word exit-ir exit-layout 8 4) = 0
]["EXIT did not use the ordinary void function terminator"]

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
	narrow: func [value [int32!] return: [int8!]][value]
} 'user "implicit integer narrowing was accepted"
assert frontend/last-error/code = frontend/ERROR-REFERENCE
	"implicit integer narrowing reported the wrong error class"

assert none? compile-text {
	Red/System []
	change-sign: func [value [int8!] return: [uint16!]][value]
} 'user "signed-to-unsigned widening was accepted"
assert frontend/last-error/code = frontend/ERROR-REFERENCE
	"signed-to-unsigned widening reported the wrong error class"

assert none? compile-text {
	Red/System []
	add: func [a [float!] b [float32!] return: [float!]][a + b]
} 'user "mixed float! and float32! arithmetic was accepted"
assert frontend/last-error/code = frontend/ERROR-REFERENCE
	"mixed floating arithmetic reported the wrong error class"

assert none? compile-text {
	Red/System []
	set-single: func [value [float32!]][value: 1.5]
} 'user "float32! assignment accepted an implicit runtime narrowing"
assert frontend/last-error/code = frontend/ERROR-REFERENCE
	"implicit float32! assignment narrowing reported the wrong error class"

assert none? compile-text {
	Red/System []
	fn: func [return: [integer!]][1 + true]
} 'user "integer arithmetic accepted a logic operand"
assert frontend/last-error/code = frontend/ERROR-REFERENCE
	"invalid binary operands reported the wrong error class"

assert none? compile-text {
	Red/System []
	fn: func [][if 1 []]
} 'user "IF accepted a non-logic condition"
assert frontend/last-error/code = frontend/ERROR-REFERENCE
	"invalid IF condition reported the wrong error class"

assert none? compile-text {
	Red/System []
	fn: func [return: [integer!]][either true [1][false]]
} 'user "expression EITHER accepted different block result types"
assert frontend/last-error/code = frontend/ERROR-REFERENCE
	"invalid EITHER results reported the wrong error class"

assert none? compile-text {
	Red/System []
	fn: func [return: [integer!]][case [true [1] false [false]]]
} 'user "expression CASE accepted different block result types"
assert frontend/last-error/code = frontend/ERROR-REFERENCE
	"invalid CASE results reported the wrong error class"

assert none? compile-text {
	Red/System []
	fn: func [value [logic!]][switch value [1 []]]
} 'user "SWITCH accepted a non-integer selector"
assert frontend/last-error/code = frontend/ERROR-REFERENCE
	"invalid SWITCH selector reported the wrong error class"

assert none? compile-text {
	Red/System []
	fn: func [value [integer!]][switch value [(1 + 2) []]]
} 'user "SWITCH accepted a computed case value"
assert frontend/last-error/code = frontend/ERROR-UNSUPPORTED
	"non-literal SWITCH value reported the wrong error class"

assert none? compile-text {
	Red/System []
	fn: func [][break]
} 'user "BREAK was accepted outside a loop"
assert frontend/last-error/code = frontend/ERROR-CONTEXT
	"invalid BREAK context reported the wrong error class"

assert none? compile-text {
	Red/System []
	fn: func [][while [continue true][]]
} 'user "CONTINUE was accepted inside a WHILE condition block"
assert frontend/last-error/code = frontend/ERROR-CONTEXT
	"invalid WHILE condition transfer reported the wrong error class"

assert none? compile-text {Red/System [] exit fn: func [][]} 'user
	"EXIT was accepted outside a function"
assert frontend/last-error/code = frontend/ERROR-CONTEXT
	"invalid EXIT context reported the wrong error class"

assert none? compile-text {
	Red/System [] fn: func [return: [integer!]][exit]
} 'user "EXIT was accepted in a value-returning function"
assert frontend/last-error/code = frontend/ERROR-REFERENCE
	"incompatible EXIT reported the wrong error class"

assert none? compile-text/limit {Red/System [] fn: func [][]} 'user 32
	"frontend ignored its output limit"
assert frontend/last-error/code = frontend/ERROR-LIMIT
	"output limit reported the wrong error class"

assert none? compile-text {Red/System []} 'user
	"frontend accepted a module without a function"
assert frontend/last-error/code = frontend/ERROR-FUNCTION-COUNT
	"missing function reported the wrong error class"

use-ir: compile-text {
	Red/System []
	fn: func [return: [integer!] /local value [integer!]][
		value: 1
		use [outer [integer!]][
			outer: 2
			use [inner [integer!]][
				inner: 3
				value: value + outer + inner
			]
		]
		use [outer [integer!]][
			outer: 4
			value: value + outer
		]
		value
	]
} 'user
assert binary? use-ir ["nested USE lowering failed: " mold frontend/last-error]
use-layout: layout-of use-ir
assert (function-word use-ir use-layout 1 28) = 3
	"non-overlapping same-name USE locals did not share their frame slot"

subroutine-ir: compile-text {
	Red/System []
	fn: func [return: [integer!] /local value [integer!] step [subroutine!]][
		value: 2
		step: [value: value + 3]
		step
		value
	]
} 'user
assert binary? subroutine-ir [
	"subroutine lowering failed: " mold frontend/last-error
]
subroutine-layout: layout-of subroutine-ir
assert all [
	(function-word subroutine-ir subroutine-layout 1 28) = 1
	not none? find ops-of subroutine-ir subroutine-layout 15
]["subroutine lowering introduced storage or missed the ordinary postfix body"]

assert none? compile-text {
	Red/System []
	fn: func [][use [step [subroutine!]][]]
} 'user "USE accepted a subroutine local"
assert frontend/last-error/code = frontend/ERROR-UNSUPPORTED
	"USE subroutine local reported the wrong error class"

assert none? compile-text {
	Red/System []
	fn: func [][
		use [value [integer!]][]
		use [value [logic!]][]
	]
} 'user "USE reused one frame slot with conflicting types"
assert frontend/last-error/code = frontend/ERROR-REFERENCE
	"conflicting USE local types reported the wrong error class"

assert none? compile-text {
	Red/System []
	fn: func [return: [integer!] /local step [subroutine!]][
		step: [step]
		step
	]
} 'user "recursive subroutine unexpectedly compiled"
assert frontend/last-error/code = frontend/ERROR-CONTEXT
	"recursive subroutine reported the wrong error class"

print "PASS: typed postfix Red/System frontend"
