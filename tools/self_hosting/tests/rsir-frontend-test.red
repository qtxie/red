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

compile-text: func [
	text [string!]
	kind [word!]
	/debug
	/limit max [integer!]
	/local source
][
	source: load text
	either debug [
		either limit [frontend/compile/debug/limit source kind max][
			frontend/compile/debug source kind
		]
	][
		either limit [frontend/compile/limit source kind max][
			frontend/compile source kind
		]
	]
]

; Offsets are derived from counts, so adding an unrelated record does not
; turn semantic tests into whole-image byte-offset tests.
layout-of: func [ir [binary!] /local types imports functions globals switches exports members
	type-at member-count import-at global-at function-at export-at use-count use-at
	initializer-count initializer-at switch-at instruction-at strings-at id record
][
	types: word-at ir 8
	imports: word-at ir 12
	functions: word-at ir 16
	globals: word-at ir 24
	switches: word-at ir 28
	exports: word-at ir 32
	type-at: 36
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
	export-at: function-at + (functions * 36)
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
	use-at: export-at + (exports * 12)
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
		switch-at initializer-at export-at
	]
]

function-word: func [ir layout id field][
	word-at ir (layout/4 + ((id - 1) * 36) + field)
]

function-instruction-word: func [
	ir layout function-id instruction-id field
	/local id global-id
][
	global-id: instruction-id
	id: 1
	while [id < function-id][
		global-id: global-id + function-word ir layout id 32
		id: id + 1
	]
	instruction-word ir layout global-id field
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

instruction-bytes: func [ir layout id /local offset size][
	offset: instruction-word ir layout id 8
	size: instruction-word ir layout id 12
	copy/part at ir (layout/7 + offset + 1) size
]

switch-word: func [ir layout id field][
	word-at ir (layout/8 + ((id - 1) * 12) + field)
]

initializer-word: func [ir layout id field][
	word-at ir (layout/9 + ((id - 1) * 16) + field)
]

export-word: func [ir layout id field][
	word-at ir (layout/10 + ((id - 1) * 12) + field)
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

op-count: func [operations [block!] operation [integer!] /local count value][
	count: 0
	foreach value operations [if value = operation [count: count + 1]]
	count
]

function-ops-of: func [
	ir [binary!]
	layout [block!]
	function-id [integer!]
	/local output id count
][
	output: make block! 8
	count: function-word ir layout function-id 32
	id: 1
	while [id <= count][
		append output function-instruction-word ir layout function-id id 0
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

alias-reflection-ir: compile-text {
	Red/System []
	sample!: alias struct! [value [integer!]]
	type-id: func [return: [integer!]][system/alias/sample!]
} 'user
assert binary? alias-reflection-ir [
	"system/alias reflection failed: " mold frontend/last-error
]
alias-reflection-layout: layout-of alias-reflection-ir
assert all [
	(ops-of alias-reflection-ir alias-reflection-layout) = [1 11]
	(instruction-word alias-reflection-ir alias-reflection-layout 1 4) = -5
	(instruction-word alias-reflection-ir alias-reflection-layout 1 8) > 1000
]["system/alias reflection did not lower directly to its integer type ID"]

assert none? compile-text {
	Red/System []
	type-id: func [return: [integer!]][system/alias/missing!]
} 'user "undefined system/alias reflection was accepted"
assert frontend/last-error/code = frontend/ERROR-REFERENCE
	"undefined system/alias reflection reported the wrong error class"

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
	(ops-of local-ir local-layout) = [1 3 5 12 3 4 11]
	(instruction-word local-ir local-layout 2 4) = 1
	(instruction-word local-ir local-layout 2 8) = 1
]["local inference did not use the ordinary address/load/set model"]

unused-local-ir: compile-text {
	Red/System []
	fn: func [return: [integer!] /local unused][7]
} 'user
assert binary? unused-local-ir [
	"unused local declaration failed: " mold frontend/last-error
]
unused-local-layout: layout-of unused-local-ir
assert all [
	(function-word unused-local-ir unused-local-layout 1 28) = 1
	(word-at unused-local-ir unused-local-layout/5) = 0
	(ops-of unused-local-ir unused-local-layout) = [1 11]
]["an unused local was not preserved as untyped declaration metadata"]

local-order-ir: compile-text {
	Red/System []
	fn: func [return: [integer!] /local unused first second][
		second: 2
		first: 1
		first + second
	]
} 'user
assert binary? local-order-ir [
	"out-of-order local inference failed: " mold frontend/last-error
]
local-order-layout: layout-of local-order-ir
assert all [
	(function-word local-order-ir local-order-layout 1 28) = 3
	(instruction-word local-order-ir local-order-layout 2 8) = 3
	(instruction-word local-order-ir local-order-layout 6 8) = 2
]["local slots did not retain declaration order"]

explicit-local-ir: compile-text {
	Red/System []
	fn: func [return: [integer!] /local value [integer!]][value: 7]
} 'user
explicit-layout: layout-of explicit-local-ir
assert all [
	(function-word explicit-local-ir explicit-layout 1 28) = 1
	(ops-of explicit-local-ir explicit-layout) = [1 3 5 11]
]["assignment result was discarded inside the assignment operation"]

grouped-local-ir: compile-text {
	Red/System []
	fn: func [
		seed [integer!]
		return: [integer!]
		/local first second [integer!]
	][
		first: second: seed
		first + second
	]
} 'user
assert binary? grouped-local-ir [
	"local assignment grouping failed: " mold frontend/last-error
]
grouped-local-layout: layout-of grouped-local-ir
assert all [
	(function-word grouped-local-ir grouped-local-layout 1 28) = 2
	(op-count ops-of grouped-local-ir grouped-local-layout frontend/set-op) = 2
	(op-count ops-of grouped-local-ir grouped-local-layout frontend/load-op) = 4
]["assignment grouping did not pass one computed value through ordinary assignments"]

grouped-global-ir: compile-text {
	Red/System []
	c: len: 0
	fn: func [return: [integer!]][c + len]
} 'user
assert binary? grouped-global-ir [
	"literal assignment grouping failed: " mold frontend/last-error
]
grouped-global-layout: layout-of grouped-global-ir
assert all [
	(word-at grouped-global-ir 24) = 2
	(global-word grouped-global-ir grouped-global-layout 1 20) = 1
	(global-word grouped-global-ir grouped-global-layout 2 20) = 1
	(initializer-word grouped-global-ir grouped-global-layout 1 8) = 0
	(initializer-word grouped-global-ir grouped-global-layout 2 8) = 0
]["literal assignment grouping did not initialize every global directly"]

pointer-either-ir: compile-text {
	Red/System []
	cell!: alias struct! [value [integer!]]
	fn: func [
		condition [logic!]
		wide [int-ptr!]
		narrow [byte-ptr!]
		return: [cell!]
	][
		as cell! either condition [wide][narrow]
	]
} 'user
assert binary? pointer-either-ir [
	"typed-pointer EITHER failed: " mold frontend/last-error
]
pointer-either-layout: layout-of pointer-either-ir
assert all [
	(op-count ops-of pointer-either-ir pointer-either-layout frontend/branch-op) = 1
	(op-count ops-of pointer-either-ir pointer-either-layout frontend/jump-op) = 1
	(op-count ops-of pointer-either-ir pointer-either-layout frontend/cast-op) = 1
]["typed-pointer EITHER did not merge before its explicit cast"]

aggregate-either-ir: compile-text {
	Red/System []
	none!: alias struct! [header [integer!]]
	object!: alias struct! [header [integer!] node [integer!]]
	fn: func [
		condition [logic!]
		none-value [none!]
		object [object!]
		return: [byte-ptr!]
	][
		as byte-ptr! either condition [none-value][object]
	]
} 'user
assert binary? aggregate-either-ir [
	"aggregate-reference EITHER failed: " mold frontend/last-error
]
aggregate-either-layout: layout-of aggregate-either-ir
assert all [
	(op-count ops-of aggregate-either-ir aggregate-either-layout frontend/branch-op) = 1
	(op-count ops-of aggregate-either-ir aggregate-either-layout frontend/jump-op) = 1
	(op-count ops-of aggregate-either-ir aggregate-either-layout frontend/cast-op) = 1
]["aggregate-reference EITHER did not preserve one pointer-valued join"]

shadow-ir: compile-text {
	Red/System []
	value: 1
	fn: func [return: [integer!] /local value][value: 11 value]
} 'user
shadow-layout: layout-of shadow-ir
assert all [
	(word-at shadow-ir 24) = 1
	(instruction-word shadow-ir shadow-layout 2 4) = 1
	(instruction-word shadow-ir shadow-layout 2 8) = 1
]["a global captured a homonymous local"]

lexical-shadow-ir: compile-text {
	Red/System []
	#enum values! [choice]
	worker: func [return: [integer!]][5]
	constant-shadow: func [return: [integer!] /local choice][
		choice: 11
		choice
	]
	function-shadow: func [return: [integer!] /local worker][
		worker: 13
		worker
	]
} 'user
assert binary? lexical-shadow-ir [
	"lexical value shadowing failed: " mold frontend/last-error
]
lexical-shadow-layout: layout-of lexical-shadow-ir
constant-shadow-ops: copy []
repeat id function-word lexical-shadow-ir lexical-shadow-layout 2 32 [
	append constant-shadow-ops function-instruction-word
		lexical-shadow-ir lexical-shadow-layout 2 id 0
]
function-shadow-ops: copy []
repeat id function-word lexical-shadow-ir lexical-shadow-layout 3 32 [
	append function-shadow-ops function-instruction-word
		lexical-shadow-ir lexical-shadow-layout 3 id 0
]
assert all [
	constant-shadow-ops = [1 3 5 12 3 4 11]
	function-shadow-ops = [1 3 5 12 3 4 11]
]["a module constant or function bypassed a homonymous local"]

category-shadow-ir: compile-text {
	Red/System []
	free: func [value [integer!] return: [integer!]][value]
	red: context [
		externals: context [
			free: 1
			size: 2
			store: func [return: [logic!]][free < size]
			address: func [return: [int-ptr!]][:free]
		]
	]
} 'user
assert binary? category-shadow-ir [
	"cross-category lexical shadowing failed: " mold frontend/last-error
]
category-shadow-layout: layout-of category-shadow-ir
category-store-id: select frontend/function-ids "red>externals>store"
assert all [
	integer? category-store-id
	(function-word category-shadow-ir category-shadow-layout category-store-id 32) = 6
]["an outer function shadowed a nearer context variable"]

keyword-shadow-ir: compile-text {
	Red/System []
	ns: context [
		overflow?: func [value [integer!] return: [logic!]][value > 0]
		positive?: func [value [integer!] return: [logic!]][overflow? value]
	]
} 'user
assert binary? keyword-shadow-ir [
	"a context function failed to shadow a language keyword: "
	mold frontend/last-error
]
keyword-shadow-layout: layout-of keyword-shadow-ir
keyword-shadow-call?: false
keyword-shadow-overflow?: false
repeat id function-word keyword-shadow-ir keyword-shadow-layout 2 32 [
	operation: function-instruction-word keyword-shadow-ir keyword-shadow-layout 2 id 0
	if all [
		operation = 7
		(function-instruction-word keyword-shadow-ir keyword-shadow-layout 2 id 4) = 1
	][keyword-shadow-call?: true]
	if operation = 23 [keyword-shadow-overflow?: true]
]
assert all [keyword-shadow-call? not keyword-shadow-overflow?]
	"a bound keyword spelling did not call its context function"

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

generic-pointer-ir: compile-text {
	Red/System []
	store: func [slot [ptr-ptr!] value [int-ptr!]][slot/value: value]
	load: func [slot [ptr-ptr!] return: [int-ptr!]][slot/value]
} 'user
assert binary? generic-pointer-ir [
	"generic pointer slot rejected a typed pointer: " mold frontend/last-error
]
assert none? find (ops-of generic-pointer-ir layout-of generic-pointer-ir) 8
	"generic pointer compatibility emitted a representation-preserving cast"

typed-pointer-mismatch-ir: compile-text {
	Red/System []
	bad: func [target [int-ptr!] source [byte-ptr!]][target: source]
} 'user
assert binary? typed-pointer-mismatch-ir [
	"frontend rejected backend-owned typed pointer compatibility: "
	mold frontend/last-error
]
assert none? find (ops-of typed-pointer-mismatch-ir layout-of typed-pointer-mismatch-ir) 8
	"typed pointer mismatch introduced a frontend CAST"

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
	to-byte: func [value [int-ptr!] return: [byte-ptr!]][as byte-ptr! value]
	to-int: func [value [byte-ptr!] return: [int-ptr!]][as int-ptr! value]
} 'user
assert binary? pointer-cast-ir [
	"explicit pointer casts failed: " mold frontend/last-error
]
pointer-cast-layout: layout-of pointer-cast-ir
assert (ops-of pointer-cast-ir pointer-cast-layout) = [3 4 8 11 3 4 8 11]
	"pointer pointee-changing casts were erased from the typed stream"

bracketed-pointer-cast-ir: compile-text {
	Red/System []
	to-typed: func [value [pointer!] return: [int-ptr!]][
		as [pointer! [integer!]] value
	]
} 'user
assert binary? bracketed-pointer-cast-ir [
	"bracketed pointer cast failed: " mold frontend/last-error
]
bracketed-pointer-cast-layout: layout-of bracketed-pointer-cast-ir
assert (ops-of bracketed-pointer-cast-ir bracketed-pointer-cast-layout) = [3 4 8 11]
	"bracketed logical type did not use the shared cast path"

pointer-compare-ir: compile-text {
	Red/System []
	same-address?: func [
		left [pointer!]
		right [pointer! [integer!]]
		return: [logic!]
	][
		left = right
	]
} 'user
assert binary? pointer-compare-ir [
	"different pointer pointees could not be compared: " mold frontend/last-error
]
pointer-compare-layout: layout-of pointer-compare-ir
assert (ops-of pointer-compare-ir pointer-compare-layout) = [3 4 3 4 15 11]
	"pointer category comparison did not use the shared binary operation"

mixed-address-ir: compile-text {
	Red/System []
	raw-add: func [value [integer!] address [int-ptr!] return: [integer!]][
		value + address
	]
	raw-subtract: func [value [integer!] address [int-ptr!] return: [integer!]][
		value - address
	]
	scaled-add: func [address [int-ptr!] offset [integer!] return: [int-ptr!]][
		address + offset
	]
} 'user
assert binary? mixed-address-ir [
	"mixed address arithmetic failed: " mold frontend/last-error
]
mixed-address-layout: layout-of mixed-address-ir
assert (ops-of mixed-address-ir mixed-address-layout) = [
	3 4 3 4 15 11
	3 4 3 4 15 11
	3 4 3 4 15 11
]["mixed address arithmetic did not use the ordinary typed binary operation"]

invalid-address-ir: compile-text {
	Red/System []
	bad: func [value [byte!] address [int-ptr!] return: [byte!]][value + address]
} 'user
assert binary? invalid-address-ir [
	"frontend rejected backend-owned byte/address legality: " mold frontend/last-error
]
assert (ops-of invalid-address-ir layout-of invalid-address-ir) = [3 4 3 4 15 11]
	"invalid address arithmetic did not remain one dense binary operation"

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
		3 20 8 3 5 12 1 3 4 3 4 21 5 12 3 4 21 4 11
	]
	(instruction-word address-index-ir address-index-layout 2 0) = 20
	(instruction-word address-index-ir address-index-layout 12 8) = 1
	(instruction-word address-index-ir address-index-layout 17 4) = 1
	(instruction-word address-index-ir address-index-layout 17 8) = 0
]["get-word and pointer indexes did not share REFERENCE/INDEX semantics"]

inline-address-ir: compile-text {
	Red/System []
	pair!: alias struct! [first [integer!] second [integer!]]
	address: func [
		return: [int-ptr!]
		/local value [pair! value]
	][
		as int-ptr! :value
	]
} 'user
assert binary? inline-address-ir [
	"inline aggregate address failed: " mold frontend/last-error
]
inline-address-layout: layout-of inline-address-ir
assert (ops-of inline-address-ir inline-address-layout) = [3 20 8 11]
	"inline aggregate address did not retain its type through the explicit cast"

inline-argument-ir: compile-text {
	Red/System []
	pair!: alias struct! [first [integer!] second [integer!]]
	read-first: func [value [pair!] return: [integer!]][value/first]
	caller: func [return: [integer!] /local value [pair! value]][
		value/first: 7
		read-first :value
	]
} 'user
assert binary? inline-argument-ir [
	"inline aggregate address argument failed: " mold frontend/last-error
]
inline-argument-layout: layout-of inline-argument-ir
assert all [
	(op-count ops-of inline-argument-ir inline-argument-layout frontend/reference-op) = 1
	(op-count ops-of inline-argument-ir inline-argument-layout frontend/cast-op) = 0
	(op-count ops-of inline-argument-ir inline-argument-layout frontend/call-op) = 1
]["inline aggregate address lost its aggregate type before the call"]

assert none? compile-text {
	Red/System []
	pair!: alias struct! [value [integer!]]
	address: func [value [pair!] return: [int-ptr!]][as int-ptr! :value]
} 'user "a referenced aggregate exposed the address of its pointer slot"
assert frontend/last-error/code = frontend/ERROR-REFERENCE
	"referenced aggregate get-word reported the wrong error class"

namespace-selection-ir: compile-text {
	Red/System []
	cell!: alias struct! [value [integer!]]
	ns: context [
		text: "red"
		cell: declare cell!
	]
	read-byte: func [return: [byte!]][ns/text/1]
	read-field: func [return: [integer!]][ns/cell/value]
} 'user
assert binary? namespace-selection-ir [
	"namespace selection failed: " mold frontend/last-error
]
namespace-selection-layout: layout-of namespace-selection-ir
namespace-selection-ops: ops-of namespace-selection-ir namespace-selection-layout
assert all [
	not none? find namespace-selection-ops 21
	not none? find namespace-selection-ops 6
]["namespace-qualified storage did not continue through INDEX/MEMBER"]

qualified-key-ir: compile-text {
	Red/System []
	a>b: 11
	a: context [b: 13]
	read: func [return: [integer!]][a>b + a/b]
} 'user
assert binary? qualified-key-ir [
	"qualified key identity failed: " mold frontend/last-error
]
qualified-key-layout: layout-of qualified-key-ir
assert all [
	(word-at qualified-key-ir 24) = 2
	(function-instruction-word qualified-key-ir qualified-key-layout 1 1 8) = 1
	(function-instruction-word qualified-key-ir qualified-key-layout 1 3 8) = 2
]["a source word collided with a namespace-qualified symbol"]

namespace-shadow-ir: compile-text {
	Red/System []
	ns: context [value: 99]
	read: func [ns [int-ptr!] return: [integer!]][ns/value]
} 'user
assert binary? namespace-shadow-ir [
	"namespace local shadow failed: " mold frontend/last-error
]
namespace-shadow-layout: layout-of namespace-shadow-ir
assert all [
	(function-instruction-word namespace-shadow-ir namespace-shadow-layout 1 1 0) = 3
	(function-instruction-word namespace-shadow-ir namespace-shadow-layout 1 1 4) = 1
]["a namespace-qualified symbol captured a homonymous local path"]

namespace-binding-ir: compile-text {
	Red/System []
	value: 10
	first: context [
		value: 20
		slot: 21
		inside: func [return: [integer!]][value]
	]
	second: context [
		value: 30
		slot: 31
	]
	root-value: func [return: [integer!]][system/words/value]
	first-value: func [return: [integer!]][first/value]
	with [second first][
		selected-value: func [return: [integer!]][value]
		write-selected: func [][slot: 32]
	]
} 'user
assert binary? namespace-binding-ir [
	"namespace binding failed: " mold frontend/last-error
]
namespace-binding-layout: layout-of namespace-binding-ir
assert all [
	(word-at namespace-binding-ir 24) = 5
	(function-instruction-word namespace-binding-ir namespace-binding-layout 1 1 4) = 2
	(function-instruction-word namespace-binding-ir namespace-binding-layout 1 1 8) = 2
	(function-instruction-word namespace-binding-ir namespace-binding-layout 2 1 8) = 1
	(function-instruction-word namespace-binding-ir namespace-binding-layout 3 1 8) = 2
	(function-instruction-word namespace-binding-ir namespace-binding-layout 4 1 8) = 4
	(function-instruction-word namespace-binding-ir namespace-binding-layout 5 2 8) = 5
]["namespace, WITH, or system/words resolved to the wrong global slot"]

forward-context-function-ir: compile-text {
	Red/System []
	red: context [
		block: context [
			select-action: func [
				return: [function! [value [integer!] return: [integer!]]]
			][
				as function! [value [integer!] return: [integer!]]
					:actions/get-action-ptr
			]
		]
		actions: context [
			get-action-ptr: func [value [integer!] return: [integer!]][value]
		]
	]
} 'user
assert binary? forward-context-function-ir [
	"forward sibling context function cast failed: " mold frontend/last-error
]
forward-context-function-layout: layout-of forward-context-function-ir
assert not none? find
	ops-of forward-context-function-ir forward-context-function-layout [3 20 8 11]
	"an explicit context function address did not retain its CAST"

casted-call-ir: compile-text {
	Red/System []
	op!: alias function! [value [integer!] return: [integer!]]
	inc: func [value [integer!] return: [integer!]][value + 1]
	select-op: func [return: [uint64!]][as uint64! :inc]
	run: func [return: [integer!] /local op [op!]][
		op: as op! select-op
		op 41
	]
} 'user
assert binary? casted-call-ir [
	"casted direct call failed: " mold frontend/last-error
]
casted-call-layout: layout-of casted-call-ir
assert all [
	(function-instruction-word casted-call-ir casted-call-layout 3 1 0) = 7
	(function-instruction-word casted-call-ir casted-call-layout 3 1 4) = 2
	(function-instruction-word casted-call-ir casted-call-layout 3 1 8) = 0
	(op-count (ops-of casted-call-ir casted-call-layout) 7) = 2
]["AS captured a direct function address instead of compiling its call"]

namespace-with-child-ir: compile-text {
	Red/System []
	base: context [value: 1]
	with base [
		child: context [
			value: 2
			read: func [return: [integer!]][value]
		]
	]
	read-base: func [return: [integer!]][base/value]
} 'user
assert binary? namespace-with-child-ir [
	"namespace nested under WITH failed: " mold frontend/last-error
]
namespace-with-child-layout: layout-of namespace-with-child-ir
assert all [
	(word-at namespace-with-child-ir 24) = 2
	(function-instruction-word namespace-with-child-ir namespace-with-child-layout 1 1 8) = 2
	(function-instruction-word namespace-with-child-ir namespace-with-child-layout 2 1 8) = 1
]["an inherited WITH captured a nearer child namespace definition"]

function-with-ir: compile-text {
	Red/System []
	first: context [value: 20]
	second: context [value: 30]
	read: func [return: [integer!] /local result][
		result: 0
		with [first second][result: value]
		result
	]
} 'user
assert binary? function-with-ir [
	"function-body WITH failed: " mold frontend/last-error
]
function-with-layout: layout-of function-with-ir
function-with-selected?: false
repeat id function-word function-with-ir function-with-layout 1 32 [
	if all [
		(function-instruction-word function-with-ir function-with-layout 1 id 0)
			= frontend/address-op
		(function-instruction-word function-with-ir function-with-layout 1 id 4)
			= frontend/global-address
		(function-instruction-word function-with-ir function-with-layout 1 id 8) = 2
	][function-with-selected?: true]
]
assert function-with-selected?
	"function-body WITH did not select the last-defined active context"

context-member-declaration-ir: compile-text {
	Red/System []
	errors: context [_throw: 0]
	initialize: func [][errors/throw: 1]
	read: func [return: [integer!]][errors/throw]
} 'user
assert binary? context-member-declaration-ir [
	"context member declaration in a function failed: " mold frontend/last-error
]
context-member-declaration-layout: layout-of context-member-declaration-ir
assert all [
	(word-at context-member-declaration-ir 24) = 2
	(function-instruction-word context-member-declaration-ir
		context-member-declaration-layout 1 2 8) = 2
	(function-instruction-word context-member-declaration-ir
		context-member-declaration-layout 2 1 8) = 2
]["a function-root context assignment did not declare one qualified global"]

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
assert (ops-of scalar-declare-ir scalar-declare-layout) = [1 3 5 12 3 4 11]
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
	(copy/part ops-of local-declare-ir local-declare-layout 5) = [3 20 3 5 12]
]["local DECLARE did not expose one pointer variable over one inline object"]

local-pointer-declare-ir: compile-text {
	Red/System []
	fn: func [return: [integer!] /local value [pointer! [integer!]]][
		value: declare pointer! [integer!]
		value/value: 73
		value/value
	]
} 'user
assert binary? local-pointer-declare-ir [
	"local pointer DECLARE failed: " mold frontend/last-error
]
local-pointer-declare-layout: layout-of local-pointer-declare-ir
assert all [
	(function-word local-pointer-declare-ir local-pointer-declare-layout 1 28) = 2
	(word-at local-pointer-declare-ir (local-pointer-declare-layout/5 + 8)) = -5
	(word-at local-pointer-declare-ir (local-pointer-declare-layout/5 + 12)) = 0
	(copy/part ops-of local-pointer-declare-ir local-pointer-declare-layout 5)
		= [3 20 3 5 12]
]["local pointer DECLARE did not address one pointee-typed storage slot"]

local-pointer-pointer-ir: compile-text {
	Red/System []
	fn: func [/local value [pointer! [pointer!]]][
		value: declare pointer! [pointer!]
	]
} 'user
assert binary? local-pointer-pointer-ir [
	"local pointer-to-pointer DECLARE failed: " mold frontend/last-error
]
local-pointer-pointer-layout: layout-of local-pointer-pointer-ir
assert all [
	(function-word local-pointer-pointer-ir local-pointer-pointer-layout 1 28) = 2
	(word-at local-pointer-pointer-ir (local-pointer-pointer-layout/5 + 8)) = -12
	(word-at local-pointer-pointer-ir (local-pointer-pointer-layout/5 + 12)) = 0
]["pointer-to-pointer DECLARE did not reserve one pointer-sized pointee slot"]

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
	not none? find inline-copy-ops [3 4 6 4 3 4 6 5]
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

aggregate-alias-ir: compile-text {
	Red/System []
	left!: alias struct! [value [integer!]]
	right!: alias struct! [value [integer!]]
	box!: alias struct! [target [left! value] source [right! value]]
	take-right: func [item [right!] return: [integer!]][item/value]
	fn: func [/local box [box!]][
		box: declare box!
		box/target: box/source
		take-right as left! box
	]
} 'user
assert binary? aggregate-alias-ir [
	"equivalent aggregate aliases failed: " mold frontend/last-error
]
aggregate-alias-layout: layout-of aggregate-alias-ir
assert all [
	(type-word aggregate-alias-ir aggregate-alias-layout 1 0) = -2
	(type-word aggregate-alias-ir aggregate-alias-layout 2 0) = -1
	(type-word aggregate-alias-ir aggregate-alias-layout 2 4) = 1
]["equivalent aggregate aliases were serialized as duplicate definitions"]

aggregate-mismatch-ir: compile-text {
	Red/System []
	left!: alias struct! [value [integer!]]
	right!: alias struct! [value [byte!]]
	box!: alias struct! [target [left! value] source [right! value]]
	fn: func [/local box [box!]][
		box: declare box!
		box/target: box/source
	]
} 'user
assert binary? aggregate-mismatch-ir [
	"frontend rejected backend-owned inline aggregate compatibility: "
	mold frontend/last-error
]
assert none? find (ops-of aggregate-mismatch-ir layout-of aggregate-mismatch-ir) 8
	"inline aggregate mismatch introduced a frontend CAST"

comment-ir: compile-text {
	Red/System []
	comment {ignored root text}
	value: func [return: [integer!]][
		comment [unknown ignored words]
		if true [comment "ignored nested text"]
		7
	]
} 'user
assert binary? comment-ir ["COMMENT statement failed: " mold frontend/last-error]

assert none? compile-text {
	Red/System []
	value: func [return: [integer!]][1 + comment {not an expression} 2]
} 'user "COMMENT was accepted inside an expression"
assert frontend/last-error/code = frontend/ERROR-REFERENCE
	"COMMENT expression misuse reported the wrong error class"

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

global-pointer-declare-ir: compile-text {
	Red/System []
	value: declare pointer! [integer!]
	fn: func [][]
} 'user
assert binary? global-pointer-declare-ir [
	"global pointer DECLARE failed: " mold frontend/last-error
]
global-pointer-declare-layout: layout-of global-pointer-declare-ir
assert all [
	(word-at global-pointer-declare-ir 24) = 2
	(global-word global-pointer-declare-ir global-pointer-declare-layout 1 12) = 0
	(global-word global-pointer-declare-ir global-pointer-declare-layout 1 20) = 1
	(global-word global-pointer-declare-ir global-pointer-declare-layout 2 4) = 0
	(global-word global-pointer-declare-ir global-pointer-declare-layout 2 8) = -5
	(global-word global-pointer-declare-ir global-pointer-declare-layout 2 12) = 0
	(global-word global-pointer-declare-ir global-pointer-declare-layout 2 20) = 0
	(initializer-word global-pointer-declare-ir global-pointer-declare-layout 1 0) = 2
	(initializer-word global-pointer-declare-ir global-pointer-declare-layout 1 4) = 2
	(initializer-word global-pointer-declare-ir global-pointer-declare-layout 1 8) = 2
]["global pointer DECLARE was not one static pointer to one pointee slot"]

static-address-cast-ir: compile-text {
	Red/System []
	parts!: alias struct! [low [integer!] high [integer!]]
	wide: #i64-4294967298
	view: as parts! :wide
	fn: func [][]
} 'user
assert binary? static-address-cast-ir [
	"static address cast failed: " mold frontend/last-error
]
static-address-cast-layout: layout-of static-address-cast-ir
static-address-source: initializer-word
	static-address-cast-ir static-address-cast-layout 2 12
assert all [
	(word-at static-address-cast-ir 24) = 2
	(initializer-word static-address-cast-ir static-address-cast-layout 2 0) = 2
	(initializer-word static-address-cast-ir static-address-cast-layout 2 4) = 2
	(initializer-word static-address-cast-ir static-address-cast-layout 2 8) = 1
	static-address-source > 0
	(type-word static-address-cast-ir static-address-cast-layout
		static-address-source 0) = -6
	(type-word static-address-cast-ir static-address-cast-layout
		static-address-source 4) = -7
]["static address cast lost its source pointer type"]

size-ir: compile-text {
	Red/System []
	sample!: alias struct! [value [integer!]]
	sample: declare sample!
	text: "Red"
	fixed-size: func [return: [integer!]][size? sample]
	member-size: func [return: [integer!]][size? sample/value]
	text-size: func [return: [integer!]][size? text]
	literal-size: func [return: [integer!]][size? "Red"]
} 'user
assert binary? size-ir ["SIZE? value lowering failed: " mold frontend/last-error]
size-layout: layout-of size-ir
assert all [
	(ops-of size-ir size-layout) = [9 11 9 11 3 4 9 11 1 11]
	(instruction-word size-ir size-layout 1 8) = 0
	(instruction-word size-ir size-layout 3 4) = -5
	(instruction-word size-ir size-layout 7 4) = -13
	(instruction-word size-ir size-layout 7 8) = 1
	(instruction-word size-ir size-layout 9 8) = 4
]["SIZE? did not distinguish static layouts from dynamic c-string values"]

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

mutable-string-ir: compile-text {
	Red/System []
	change: func [return: [byte!] /local text [c-string!]][
		text: "A"
		text/1: #"B"
		text/1
	]
} 'user
assert binary? mutable-string-ir [
	"mutable c-string literal failed: " mold frontend/last-error
]
mutable-string-layout: layout-of mutable-string-ir
mutable-string-ref: global-word mutable-string-ir mutable-string-layout 1 8
mutable-string-ops: ops-of mutable-string-ir mutable-string-layout
assert all [
	(word-at mutable-string-ir 24) = 1
	(type-word mutable-string-ir mutable-string-layout mutable-string-ref 0) = -7
	(type-word mutable-string-ir mutable-string-layout mutable-string-ref 4) = -15
	(global-word mutable-string-ir mutable-string-layout 1 4) = 0
	(global-word mutable-string-ir mutable-string-layout 1 12) = 1
	(global-word mutable-string-ir mutable-string-layout 1 20) = 1
	(initializer-word mutable-string-ir mutable-string-layout 1 0) = 3
	(initializer-word mutable-string-ir mutable-string-layout 1 8) = 2
	none? find mutable-string-ops 2
	not none? find mutable-string-ops 20
	not none? find mutable-string-ops 21
	(instruction-word mutable-string-ir mutable-string-layout 2 4) = -13
]["c-string literal did not use writable hidden byte storage"]

unicode-string: make string! 1
append unicode-string to char! 256
unicode-bytes: to binary! unicode-string
assert unicode-bytes = #{C480} "test host did not encode U+0100 as UTF-8"
append unicode-bytes 0
unicode-string-ir: frontend/compile compose/deep [
	Red/System []
	read-unicode: func [return: [byte!] /local text [c-string!]][
		text: (unicode-string)
		text/2
	]
	unicode-size: func [return: [integer!]][size? (unicode-string)]
] 'user
assert binary? unicode-string-ir [
	"Unicode c-string literal failed: " mold frontend/last-error
]
unicode-string-layout: layout-of unicode-string-ir
unicode-string-offset: initializer-word
	unicode-string-ir unicode-string-layout 1 4
unicode-string-size: initializer-word unicode-string-ir unicode-string-layout 1 8
unicode-size-literals: 0
repeat id word-at unicode-string-ir 20 [
	if all [
		(instruction-word unicode-string-ir unicode-string-layout id 0) = 1
		(instruction-word unicode-string-ir unicode-string-layout id 4) = -5
		(instruction-word unicode-string-ir unicode-string-layout id 8) = 3
	][unicode-size-literals: unicode-size-literals + 1]
]
assert all [
	(word-at unicode-string-ir 24) = 1
	(initializer-word unicode-string-ir unicode-string-layout 1 0) = 3
	unicode-string-size = 3
	(copy/part at unicode-string-ir
		(unicode-string-layout/7 + unicode-string-offset + 1)
		unicode-string-size) = unicode-bytes
	unicode-size-literals = 1
]["Unicode c-string literal was not encoded as UTF-8"]

packed-string-ir: compile-text {
	Red/System []
	read-packed: func [return: [byte!] /local text [c-string!]][
		text: as c-string! #{00838000}
		text/2
	]
} 'user
assert binary? packed-string-ir [
	"binary-to-c-string cast failed: " mold frontend/last-error
]
packed-string-layout: layout-of packed-string-ir
packed-string-offset: initializer-word packed-string-ir packed-string-layout 1 4
packed-string-size: initializer-word packed-string-ir packed-string-layout 1 8
assert all [
	(word-at packed-string-ir 24) = 1
	(initializer-word packed-string-ir packed-string-layout 1 0) = 3
	packed-string-size = 4
	(copy/part at packed-string-ir
		(packed-string-layout/7 + packed-string-offset + 1)
		packed-string-size) = #{00838000}
	(instruction-word packed-string-ir packed-string-layout 1 0) = 3
	(instruction-word packed-string-ir packed-string-layout 1 8) = 1
	(instruction-word packed-string-ir packed-string-layout 2 0) = 20
	(instruction-word packed-string-ir packed-string-layout 2 4) = -13
	(instruction-word packed-string-ir packed-string-layout 3 0) = 8
	(instruction-word packed-string-ir packed-string-layout 3 4) = -13
]["explicit binary-to-c-string cast did not preserve raw bytes"]

assert none? compile-text {
	Red/System []
	values: [1 2]
	values: [3 4]
	fn: func [][]
} 'user "a literal array pointer was reassigned"
assert frontend/last-error/code = frontend/ERROR-REFERENCE
	"literal array reassignment reported the wrong error class"

array-cursor-ir: compile-text {
	Red/System []
	names-buf: protect ["zero" "one"]
	advance: func [/local names][
		names: names-buf
		names: names + 1
	]
} 'user
assert binary? array-cursor-ir [
	"a cursor derived from literal array storage could not be reassigned: "
	mold frontend/last-error
]

array-pointer-comparison-ir: compile-text {
	Red/System []
	values: protect [1 2 3]
	past?: func [end [int-ptr!] return: [logic!]][
		values + size? values > end
	]
} 'user
assert binary? array-pointer-comparison-ir [
	"literal array cursor comparison failed: " mold frontend/last-error
]

invalid-array-comparison-ir: compile-text {
	Red/System []
	values: [1 2 3]
	bad: func [end [byte-ptr!] return: [logic!]][values > end]
} 'user
assert binary? invalid-array-comparison-ir [
	"frontend rejected backend-owned array comparison legality: "
	mold frontend/last-error
]
assert not none? find
	(ops-of invalid-array-comparison-ir layout-of invalid-array-comparison-ir) 15
	"invalid array comparison did not reach the generic binary operation"

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
	function-address: func [return: [byte-ptr!]][as byte-ptr! :triple]
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

mixed-address-array-ir: compile-text {
	Red/System []
	values: ["one" 1 "two"]
	fn: func [][]
} 'user
assert binary? mixed-address-array-ir [
	"mixed address literal array failed: " mold frontend/last-error
]
mixed-address-layout: layout-of mixed-address-array-ir
mixed-address-ref: global-word mixed-address-array-ir mixed-address-layout 1 8
assert all [
	(type-word mixed-address-array-ir mixed-address-layout mixed-address-ref 4) = -8
	(type-word mixed-address-array-ir mixed-address-layout mixed-address-ref 8) = 8
	(initializer-word mixed-address-array-ir mixed-address-layout 1 0) = 2
	(initializer-word mixed-address-array-ir mixed-address-layout 1 12) = -13
	(initializer-word mixed-address-array-ir mixed-address-layout 3 0) = 2
	(initializer-word mixed-address-array-ir mixed-address-layout 3 12) = -13
]["mixed address literal array lost its source types or 64-bit slot layout"]

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

contextual-null-ir: compile-text {
	Red/System []
	take-byte: func [value [byte!]][value: value]
	take-integer: func [value [integer!]][value: value]
	take-logic: func [value [logic!]][value: value]
	take-float: func [value [float!]][value: value]
	take-pointer: func [value [pointer! [integer!]]][value: value]
	use: func [][
		take-byte null
		take-integer null
		take-logic null
		take-float null
		take-pointer null
	]
} 'user
assert binary? contextual-null-ir [
	"contextual null literal failed: " mold frontend/last-error
]
contextual-null-layout: layout-of contextual-null-ir
assert none? find (ops-of contextual-null-ir contextual-null-layout) 8
	"contextual null literal emitted a runtime cast"
contextual-null-count: 0
repeat id word-at contextual-null-ir 20 [
	if all [
		(instruction-word contextual-null-ir contextual-null-layout id 0) = 1
		(instruction-word contextual-null-ir contextual-null-layout id 4) = -14
	][contextual-null-count: contextual-null-count + 1]
]
assert contextual-null-count = 5
	"contextual null literals were retagged before native sinks"

assert binary? compile-text {
	Red/System []
	inc: func [value [integer!] return: [integer!]][value + 1]
	address: func [return: [integer!]][as integer! :inc]
} 'user "function-to-integer cast was rejected"

invalid-function-cast-ir: compile-text {
	Red/System []
	inc: func [value [integer!] return: [integer!]][value + 1]
	bad: func [return: [byte!]][as byte! :inc]
} 'user
assert binary? invalid-function-cast-ir [
	"frontend rejected backend-owned function cast legality: " mold frontend/last-error
]
assert not none? find (ops-of invalid-function-cast-ir
	layout-of invalid-function-cast-ir) frontend/cast-op
	"invalid function cast did not reach native codegen"

function-integer-cast-ir: compile-text {
	Red/System []
	callback!: alias function! [[custom] return: [integer!]]
	address: func [return: [uint64!]][as uint64! :address]
	from-table: func [
		table [pointer! [uint64!]]
		/local callback [callback!]
	][callback: as callback! table/1]
} 'user
assert binary? function-integer-cast-ir [
	"32/64-bit integer function cast failed: " mold frontend/last-error
]

invalid-narrow-function-cast-ir: compile-text {
	Red/System []
	callback!: alias function! [return: [integer!]]
	bad: func [value [uint16!] return: [callback!]][as callback! value]
} 'user
assert binary? invalid-narrow-function-cast-ir [
	"frontend rejected backend-owned narrow function cast: " mold frontend/last-error
]
assert not none? find (ops-of invalid-narrow-function-cast-ir
	layout-of invalid-narrow-function-cast-ir) frontend/cast-op
	"narrow function cast did not reach native codegen"

system-aggregate-root-ir: compile-text {
	Red/System []
	system!: alias struct! [boot-data [byte-ptr!]]
	#import [
		"runtime.dll" cdecl [
			system: "system" [system!]
		]
	]
	system/boot-data: #{0102}
	read-boot-data: func [return: [byte-ptr!]][system/boot-data]
} 'glue
assert binary? system-aggregate-root-ir [
	"root imported aggregate field assignment failed: " mold frontend/last-error
]

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

callback-mismatch-ir: compile-text {
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
} 'user
assert binary? callback-mismatch-ir [
	"frontend rejected backend-owned callback compatibility: " mold frontend/last-error
]
assert none? find (ops-of callback-mismatch-ir layout-of callback-mismatch-ir) 8
	"callback mismatch introduced a frontend CAST"

assert binary? compile-text {
	Red/System []
	op!: alias function! [value [integer!] return: [integer!]]
	wrong: func [value [byte!] return: [integer!]][value]
	bad: func [return: [integer!] /local fn [op!]][
		fn: as op! :wrong
		fn 4
	]
} 'user "explicit function-to-function cast was rejected"

explicit-null-cast-ir: compile-text {
	Red/System []
	op!: alias function! [value [integer!] return: [integer!]]
	bad: func [return: [integer!]][as op! null]
} 'user
assert binary? explicit-null-cast-ir [
	"frontend rejected backend-owned explicit null cast: " mold frontend/last-error
]
assert not none? find (ops-of explicit-null-cast-ir
	layout-of explicit-null-cast-ir) frontend/cast-op
	"explicit null cast did not reach native codegen"

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

invalid-pointer-index-ir: compile-text {
	Red/System []
	fn: func [p [int-ptr!] index [logic!] return: [integer!]][p/index]
} 'user
assert binary? invalid-pointer-index-ir [
	"frontend rejected backend-owned pointer index type: " mold frontend/last-error
]
assert not none? find (ops-of invalid-pointer-index-ir
	layout-of invalid-pointer-index-ir) frontend/index-op
	"invalid pointer index did not reach native INDEX"

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

red-internal-variadic-ir: compile-text {
	Red/System []
	#import [
		"foo.dll" stdcall [
			sink: "sink" [
				[variadic red-internal]
				count [integer!]
				list [int-ptr!]
				return: [integer!]
			]
		]
	]
	main: func [return: [integer!]][sink [11 22]]
} 'user
assert binary? red-internal-variadic-ir [
	"Red-internal variadic import failed: " mold frontend/last-error
]
red-internal-variadic-layout: layout-of red-internal-variadic-ir
assert all [
	(word-at red-internal-variadic-ir
		(red-internal-variadic-layout/2 + 20)) = 522
	(word-at red-internal-variadic-ir
		(red-internal-variadic-layout/2 + 24)) = 0
	(word-at red-internal-variadic-ir
		(red-internal-variadic-layout/2 + 28)) = 2
]["Red-internal variadic import lost its packed signature"]

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
repeat id word-at cdecl-variadic-ir 20 [
	if (instruction-word cdecl-variadic-ir cdecl-variadic-layout id 0) = 7 [
		cdecl-variadic-call: id
	]
]
assert all [
	(function-word cdecl-variadic-ir cdecl-variadic-layout 1 12) = 9
	cdecl-variadic-call > 0
	none? find (ops-of cdecl-variadic-ir cdecl-variadic-layout) 8
	(instruction-word cdecl-variadic-ir cdecl-variadic-layout
		cdecl-variadic-call 8) = 2
]["cdecl variadic promotion did not remain a native CALL concern"]

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

scalar-variadic-ir: compile-text {
	Red/System []
	collect: func [
		[variadic]
		count [integer!]
		list [int-ptr!]
		return: [integer!]
	][count]
	main: func [return: [integer!]][collect 1]
} 'user
assert binary? scalar-variadic-ir [
	"scalar native variadic call failed: " mold frontend/last-error
]
scalar-variadic-layout: layout-of scalar-variadic-ir
scalar-variadic-call: 0
repeat id word-at scalar-variadic-ir 20 [
	if (instruction-word scalar-variadic-ir scalar-variadic-layout id 0) = 7 [
		scalar-variadic-call: id
	]
]
assert all [
	scalar-variadic-call > 0
	(instruction-word scalar-variadic-ir scalar-variadic-layout
		scalar-variadic-call 8) = 1
]["scalar native variadic call lost its single expression"]

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

typed-scalar-ir: compile-text {
	Red/System []
	typed-value!: alias struct! [
		type [integer!]
		_align0 [integer!]
		value [int-ptr!]
		_padding [integer!]
		_align1 [integer!]
	]
	sink: func [
		[typed]
		count [integer!]
		list [typed-value!]
		return: [integer!]
	][count]
	main: func [return: [integer!]][
		sink 40 + 2
		sink [42]
	]
} 'user
assert binary? typed-scalar-ir [
	"scalar typed call failed: " mold frontend/last-error
]
typed-scalar-layout: layout-of typed-scalar-ir
typed-single-calls: copy []
repeat id word-at typed-scalar-ir 20 [
	if (instruction-word typed-scalar-ir typed-scalar-layout id 0) = 7 [
		repend typed-single-calls [
			instruction-word typed-scalar-ir typed-scalar-layout id 8
			instruction-word typed-scalar-ir typed-scalar-layout id 12
		]
	]
]
assert all [
	(length? typed-single-calls) = 4
	typed-single-calls/1 = 1
	typed-single-calls/3 = 1
	typed-single-calls/2 = typed-single-calls/4
]["scalar and one-item-block typed calls did not share one call shape"]

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

global-infix-ir: compile-text {
	Red/System []
	add: func [[infix] left [integer!] right [integer!] return: [integer!]][
		left + right
	]
	value: 2 add 3
} 'glue
assert binary? global-infix-ir [
	"global infix initializer failed: " mold frontend/last-error
]
assert not none? find (ops-of global-infix-ir layout-of global-infix-ir) 7
	"global literal folding consumed the left operand of an infix expression"

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

release-assert-ir: compile-text {
	Red/System []
	predicate: func [return: [logic!]][true]
	fn: func [][assert predicate]
} 'user
release-without-assert-ir: compile-text {
	Red/System []
	predicate: func [return: [logic!]][true]
	fn: func [][]
} 'user
assert release-assert-ir = release-without-assert-ir
	"release ASSERT left instructions or metadata in RSIR"

debug-assert-ir: compile-text/debug {
	Red/System []
	predicate: func [return: [logic!]][true]
	fn: func [][assert predicate]
} 'user
assert binary? debug-assert-ir [
	"debug ASSERT lowering failed: " mold frontend/last-error
]
debug-assert-layout: layout-of debug-assert-ir
assert all [
	(function-word debug-assert-ir debug-assert-layout 2 32) = 4
	(function-instruction-word debug-assert-ir debug-assert-layout 2 1 0) = 7
	(function-instruction-word debug-assert-ir debug-assert-layout 2 2 0) = 17
	(function-instruction-word debug-assert-ir debug-assert-layout 2 2 4) = 4
	(function-instruction-word debug-assert-ir debug-assert-layout 2 2 8) = 1
	(function-instruction-word debug-assert-ir debug-assert-layout 2 3 0) = 19
	(function-instruction-word debug-assert-ir debug-assert-layout 2 3 4) = 98
	(function-instruction-word debug-assert-ir debug-assert-layout 2 4 0) = 11
]["debug ASSERT did not use the shared branch/fail path"]

release-invalid-assert-ir: compile-text {
	Red/System []
	fn: func [][assert 1]
} 'user
assert binary? release-invalid-assert-ir [
	"release ASSERT did not follow the legacy ignored-expression rule: "
	mold frontend/last-error
]
release-invalid-assert-layout: layout-of release-invalid-assert-ir
assert (function-ops-of release-invalid-assert-ir
	release-invalid-assert-layout 1) = [11]
	"release ASSERT retained its ignored condition in RSIR"

debug-invalid-assert-ir: compile-text/debug {
	Red/System []
	fn: func [][assert 1]
} 'user
assert binary? debug-invalid-assert-ir [
	"frontend rejected backend-owned debug ASSERT predicate: "
	mold frontend/last-error
]
assert (function-ops-of debug-invalid-assert-ir
	layout-of debug-invalid-assert-ir 1) = [1 17 19 11]
	"invalid debug ASSERT did not reach native BRANCH validation"

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
	(ops-of if-ir if-layout) = [1 3 5 12 3 4 17 1 3 5 12 3 4 11]
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
	(ops-of either-statement-ir either-statement-layout) = [3 4 17 1 12 16 1 12 11]
	(instruction-word either-statement-ir either-statement-layout 6 8) = 0
]["statement EITHER did not discard each unused arm value directly"]

null-selection-ir: compile-text {
	Red/System []
	handle!: alias pointer! [integer!]
	from-either: func [flag [logic!] value [handle!] return: [handle!]][
		either flag [value][null]
	]
	from-case: func [flag [logic!] value [handle!] return: [handle!]][
		case [flag [null] true [value]]
	]
	from-switch: func [key [integer!] value [handle!] return: [handle!]][
		switch key [0 [null] default [value]]
	]
} 'user
assert binary? null-selection-ir [
	"reference/null selection failed: " mold frontend/last-error
]
assert (op-count ops-of null-selection-ir layout-of null-selection-ir
	frontend/cast-op) = 0
	"polymorphic null selection introduced a frontend sink CAST"

null-aggregate-selection-ir: compile-text {
	Red/System []
	cell!: alias struct! [header [integer!] data [integer!]]
	block!: alias struct! [header [integer!] head [integer!]]
	choose: func [
		flag [logic!]
		source [cell!]
		return: [block!]
		/local out [block!]
	][
		out: either flag [null][source]
		out
	]
	cast-selection: func [flag [logic!] source [cell!] return: [cell!]][
		as cell! either flag [null][source]
	]
} 'user
assert binary? null-aggregate-selection-ir [
	"polymorphic null selection failed: " mold frontend/last-error
]
assert (op-count ops-of null-aggregate-selection-ir
	layout-of null-aggregate-selection-ir frontend/cast-op) = 1
	"polymorphic null selection did not retain only its explicit CAST"

struct-mismatch-ir: compile-text {
	Red/System []
	cell!: alias struct! [header [integer!] data [integer!]]
	block!: alias struct! [header [integer!] head [integer!]]
	bad: func [source [cell!] /local out [block!]][out: source]
} 'user
assert binary? struct-mismatch-ir [
	"frontend rejected backend-owned aggregate compatibility: " mold frontend/last-error
]
assert none? find (ops-of struct-mismatch-ir layout-of struct-mismatch-ir) 8
	"aggregate mismatch introduced a frontend CAST"

nested-selection-statements-ir: compile-text {
	Red/System []
	from-either: func [flag [logic!]][
		either flag [case [true [1] true [true]]][
			switch 1 [1 [1] default [true]]
		]
	]
	from-case: func [flag [logic!]][
		case [true [either flag [1][true]]]
	]
	from-switch: func [flag [logic!]][
		switch 1 [1 [either flag [1][true]] default [0]]
	]
} 'user
assert binary? nested-selection-statements-ir [
	"nested statement selections failed: " mold frontend/last-error
]

nested-invalid-selection-ir: compile-text {
	Red/System []
	fn: func [flag [logic!] return: [integer!]][
		either flag [case [true [1] true [true]]][1]
	]
} 'user
assert binary? nested-invalid-selection-ir [
	"frontend rejected backend-owned nested selection merge: " mold frontend/last-error
]
assert none? find (ops-of nested-invalid-selection-ir
	layout-of nested-invalid-selection-ir) frontend/drop-op
	"invalid nested selection was reshaped by frontend DROP operations"

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
switch-miss-fail: index? find switch-miss-ops 19
assert all [
	integer? switch-miss-fail
	(instruction-word switch-miss-ir switch-miss-layout switch-miss-fail 4) = 101
]["statement SWITCH without DEFAULT did not raise runtime error 101 on no match"]

switch-value-ir: compile-text {
	Red/System []
	choose: func [value [integer!] return: [integer!]][
		switch value [1 [7]]
	]
} 'user
assert binary? switch-value-ir [
	"value SWITCH without DEFAULT failed: " mold frontend/last-error
]
switch-value-layout: layout-of switch-value-ir
switch-value-ops: ops-of switch-value-ir switch-value-layout
switch-value-fail: index? find switch-value-ops 19
assert all [
	integer? switch-value-fail
	(instruction-word switch-value-ir switch-value-layout switch-value-fail 4) = 101
]["value SWITCH without DEFAULT lost its non-returning no-match path"]

switch-assert-tail-ir: compile-text {
	Red/System []
	choose: func [value [integer!] return: [integer!]][
		switch value [1 [7] default [assert false]]
	]
} 'user
assert binary? switch-assert-tail-ir [
	"tail ASSERT false did not terminate a value SWITCH edge: "
	mold frontend/last-error
]
switch-assert-tail-layout: layout-of switch-assert-tail-ir
switch-assert-tail-ops: ops-of switch-assert-tail-ir switch-assert-tail-layout
switch-assert-tail-fail: index? find switch-assert-tail-ops 19
assert all [
	integer? switch-assert-tail-fail
	(instruction-word switch-assert-tail-ir switch-assert-tail-layout
		switch-assert-tail-fail 4) = 98
]["tail ASSERT false did not use the assertion failure terminator"]

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
tagged-member-at: 36 + ((word-at tagged-ir 8) * 20)
tagged-write?: false
repeat id word-at tagged-ir 20 [
	if all [
		(instruction-word tagged-ir tagged-layout id 0) = 6
		(instruction-word tagged-ir tagged-layout id 8) = 1
	][tagged-write?: true]
]
assert all [
	(word-at tagged-ir 8) = 2
	(word-at tagged-ir 36) = -3
	(word-at tagged-ir 44) = 1
	(word-at tagged-ir 52) = 2
	(word-at tagged-ir tagged-member-at) = 2
	(word-at tagged-ir (tagged-member-at + 4)) = 1
	(word-at tagged-ir (tagged-member-at + 8)) = -5
	(word-at tagged-ir (tagged-member-at + 12)) = 0
	tagged-write?
	not none? find tagged-ops 22
	none? find tagged-ops 19
	(switch-word tagged-ir tagged-layout 1 0) = 1
	(switch-word tagged-ir tagged-layout 2 0) = 2
]["tagged union did not retain one tagged layout and ordinary member/tag operations"]

non-exhaustive-tagged-switch-ir: compile-text {
	Red/System []
	event!: alias union! [[variant] mouse [integer!] key [integer!]]
	inspect: func [return: [integer!] /local event [event!]][
		event: declare event!
		switch event [mouse [1] key [2]]
	]
} 'user
assert binary? non-exhaustive-tagged-switch-ir [
	"frontend rejected backend-owned tagged SWITCH depth merge: "
	mold frontend/last-error
]
assert (op-count (ops-of non-exhaustive-tagged-switch-ir
	layout-of non-exhaustive-tagged-switch-ir) frontend/drop-op) = 1
	"non-exhaustive tagged SWITCH added a merge-repair DROP"

raw-variant-ir: compile-text {
	Red/System []
	raw!: alias union! [value [integer!]]
	fn: func [raw [raw!] return: [logic!]][variant? raw 'value]
} 'user
assert binary? raw-variant-ir [
	"frontend rejected backend-owned VARIANT? type: " mold frontend/last-error
]
assert not none? find (ops-of raw-variant-ir layout-of raw-variant-ir) frontend/tag-op
	"raw union VARIANT? did not reach native TAG"

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

positive-wide-ir: compile-text {
	Red/System []
	value: func [return: [int64!]][#i64-4294967296]
} 'user
assert binary? positive-wide-ir [
	"positive signed 64-bit literal failed: " mold frontend/last-error
]
positive-wide-layout: layout-of positive-wide-ir
assert all [
	(instruction-word positive-wide-ir positive-wide-layout 1 4) = -7
	(instruction-word positive-wide-ir positive-wide-layout 1 8) = 0
	(instruction-word positive-wide-ir positive-wide-layout 1 12) = 1
]["positive signed 64-bit literal did not retain both limbs"]

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

enum-bitwise-ir: compile-text {
	Red/System []
	#enum encoding! [Latin1: 1 UCS-2: 2 UCS-4: 4]
	flags: func [unit [encoding!] return: [integer!]][F0h or unit]
} 'user
assert binary? enum-bitwise-ir [
	"enum bitwise compatibility failed: " mold frontend/last-error
]
enum-bitwise-layout: layout-of enum-bitwise-ir
assert all [
	(type-word enum-bitwise-ir enum-bitwise-layout 1 0) = 5
	(ops-of enum-bitwise-ir enum-bitwise-layout) = [1 3 4 15 11]
	(instruction-word enum-bitwise-ir enum-bitwise-layout 4 4) = 10
]["enum identity or integer compatibility was lost during bitwise lowering"]

enum-shared-value-ir: compile-text {
	Red/System []
	#enum values! [first: second: 10 third fourth: fifth: 20 sixth]
	sum: func [return: [integer!]][
		first + second + third + fourth + fifth + sixth
	]
} 'user
assert binary? enum-shared-value-ir [
	"shared enum value lowering failed: " mold frontend/last-error
]
enum-shared-value-layout: layout-of enum-shared-value-ir
assert all [
	(instruction-word enum-shared-value-ir enum-shared-value-layout 1 8) = 10
	(instruction-word enum-shared-value-ir enum-shared-value-layout 2 8) = 10
	(instruction-word enum-shared-value-ir enum-shared-value-layout 4 8) = 11
	(instruction-word enum-shared-value-ir enum-shared-value-layout 6 8) = 20
	(instruction-word enum-shared-value-ir enum-shared-value-layout 8 8) = 20
	(instruction-word enum-shared-value-ir enum-shared-value-layout 10 8) = 21
]["a chained enum assignment did not bind every label to the shared value"]

enum-size-ir: compile-text {
	Red/System []
	#enum states! [first: second: 10 third fourth: fifth: 20 sixth]
	count: func [return: [integer!]][size? states!]
} 'user
assert binary? enum-size-ir [
	"enum SIZE? lowering failed: " mold frontend/last-error
]
enum-size-layout: layout-of enum-size-ir
assert all [
	(function-instruction-word enum-size-ir enum-size-layout 1 1 0) = frontend/literal-op
	(function-instruction-word enum-size-ir enum-size-layout 1 1 4) = -5
	(function-instruction-word enum-size-ir enum-size-layout 1 1 8) = 6
]["enum SIZE? did not return the number of declared labels"]

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
	(ops-of widen-ir widen-layout) = [3 4 3 5 12 3 4 11]
	(instruction-word widen-ir widen-layout 4 4) = 0
	(instruction-word widen-ir widen-layout 8 4) = -7
]["lossless assignment/return widening was not left to codegen"]

early-widen-ir: compile-text {
	Red/System []
	widen: func [value [int8!] return: [int64!]][return value]
} 'user
assert binary? early-widen-ir [
	"explicit RETURN widening failed: " mold frontend/last-error
]
early-widen-layout: layout-of early-widen-ir
assert all [
	(ops-of early-widen-ir early-widen-layout) = [3 4 11]
	(instruction-word early-widen-ir early-widen-layout 3 4) = -7
]["explicit RETURN widening was not left to codegen"]

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
	(ops-of widen-call-ir widen-call-layout) = [3 4 11 3 4 7 11 1 11]
	(instruction-word widen-call-ir widen-call-layout 6 4) = 1
	(function-word widen-call-ir widen-call-layout 3 12) = 1
	(instruction-word widen-call-ir widen-call-layout 9 8) = 0
]["argument widening was not left to codegen or return flags are incorrect"]

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
	(ops-of enum-widen-ir enum-widen-layout) = [3 4 11]
	(instruction-word enum-widen-ir enum-widen-layout 3 4) = -7
]["logical integer widening was not left to codegen"]

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

integer-float-cast-ir: compile-text {
	Red/System []
	value: func [return: [float!]][as float! 1]
} 'user
assert binary? integer-float-cast-ir [
	"integer-to-float literal cast failed: " mold frontend/last-error
]
integer-float-cast-layout: layout-of integer-float-cast-ir
assert all [
	(ops-of integer-float-cast-ir integer-float-cast-layout) = [1 8 11]
	(instruction-word integer-float-cast-ir integer-float-cast-layout 1 4) = -5
	(instruction-word integer-float-cast-ir integer-float-cast-layout 2 4) = -10
]["integer-to-float cast was folded into a direct float literal"]

mixed-float-ir: compile-text {
	Red/System []
	mixed: func [
		x [float32!]
		e [float32!]
		return: [float32!]
	][
		as float32! -1.0 * x * e
	]
} 'user
assert binary? mixed-float-ir [
	"mixed float!/float32! arithmetic failed: " mold frontend/last-error
]
mixed-float-layout: layout-of mixed-float-ir
assert (ops-of mixed-float-ir mixed-float-layout) = [1 3 4 15 3 4 15 8 11]
	"mixed floating arithmetic did not retain its explicit result CAST"

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
	(ops-of float-argument-ir float-argument-layout) = [3 4 11 1 7 11]
	(instruction-word float-argument-ir float-argument-layout 4 4) = -10
]["float argument literal did not remain unmodified for native CALL coercion"]

short-ir: compile-text {
	Red/System []
	fn: func [a [logic!] b [logic!] return: [logic!]][any [a b]]
} 'user
short-layout: layout-of short-ir
assert all [
	(function-word short-ir short-layout 1 28) = 0
	(ops-of short-ir short-layout) = [
		3 4 17 3 4 17 1 16 1 11
	]
	(instruction-word short-ir short-layout 3 8) = 1
	(instruction-word short-ir short-layout 3 4) = 9
	(instruction-word short-ir short-layout 6 4) = 9
	(instruction-word short-ir short-layout 8 4) = 10
]["ANY did not merge its short-circuit result on the typed stack"]

single-all-ir: compile-text {
	Red/System []
	fn: func [value [logic!] return: [logic!]][all [value]]
} 'user
single-all-layout: layout-of single-all-ir
assert all [
	(function-word single-all-ir single-all-layout 1 28) = 0
	(ops-of single-all-ir single-all-layout) = [3 4 17 1 16 1 11]
	(instruction-word single-all-ir single-all-layout 3 8) = 0
]["a one-condition ALL did not reach native BRANCH validation"]

condition-statements-ir: compile-text {
	Red/System []
	touch: func [][]
	all-unit: func [return: [logic!]][all [true touch]]
	any-unit: func [return: [logic!]][any [false touch]]
} 'user
assert binary? condition-statements-ir [
	"ANY/ALL statement identity failed: " mold frontend/last-error
]

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
	(ops-of exit-ir exit-layout) = [1 3 5 12 3 4 17 11 1 3 5 12 11]
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

library-ir: compile-text {
	Red/System []
	value: 1
	value: value + 1
	#user-code
	value: value + 2
	#user-code
	value: value + 4
	answer: func [return: [integer!]][value]
	#export stdcall [answer "answer-v1" value]
} 'library
assert binary? library-ir [
	"shared library lowering failed: " mold frontend/last-error
]
library-layout: layout-of library-ir
first-export-name: to string! copy/part at library-ir
	(library-layout/7 + (export-word library-ir library-layout 1 4) + 1)
	(export-word library-ir library-layout 1 8)
second-export-name: to string! copy/part at library-ir
	(library-layout/7 + (export-word library-ir library-layout 2 4) + 1)
	(export-word library-ir library-layout 2 8)
assert all [
	(word-at library-ir 0) = 4
	(word-at library-ir 4) = 0
	(word-at library-ir 16) = 7
	(word-at library-ir 32) = 2
	(function-word library-ir library-layout 1 12) = 66
	(function-word library-ir library-layout 6 32) = 8
	(function-word library-ir library-layout 7 32) = 15
	(export-word library-ir library-layout 1 0) = 1
	(export-word library-ir library-layout 2 0) = -1
	first-export-name = "answer-v1"
	second-export-name = "value"
]["shared library exports or boot/user module boundaries lost their semantics"]

runtime-library-ir: frontend/compile/runtime load {
	Red/System []
	red: context [
		state: 1
		boot: func [value [integer!] return: [integer!]][value]
	]
	exec: context [
		helper: func [][]
		nested: context [hidden: func [][]]
	]
} 'library [
	red/boot "red/boot"
	red/state "red/state"
]
assert binary? runtime-library-ir [
	"runtime library lowering failed: " mold frontend/last-error
]
runtime-library-layout: layout-of runtime-library-ir
runtime-boot-id: select frontend/function-ids "red>boot"
runtime-helper-id: select frontend/function-ids "exec>helper"
runtime-first-export-name: to string! copy/part at runtime-library-ir
	(runtime-library-layout/7
		+ (export-word runtime-library-ir runtime-library-layout 1 4) + 1)
	(export-word runtime-library-ir runtime-library-layout 1 8)
runtime-second-export-name: to string! copy/part at runtime-library-ir
	(runtime-library-layout/7
		+ (export-word runtime-library-ir runtime-library-layout 2 4) + 1)
	(export-word runtime-library-ir runtime-library-layout 2 8)
runtime-third-export-name: to string! copy/part at runtime-library-ir
	(runtime-library-layout/7
		+ (export-word runtime-library-ir runtime-library-layout 3 4) + 1)
	(export-word runtime-library-ir runtime-library-layout 3 8)
assert all [
	(word-at runtime-library-ir 32) = 3
	(function-word runtime-library-ir runtime-library-layout runtime-boot-id 12) = 578
	(function-word runtime-library-ir runtime-library-layout runtime-helper-id 12) = 578
	(export-word runtime-library-ir runtime-library-layout 1 0) = runtime-boot-id
	(export-word runtime-library-ir runtime-library-layout 2 0) < 0
	(export-word runtime-library-ir runtime-library-layout 3 0) = runtime-helper-id
	runtime-first-export-name = "red/boot"
	runtime-second-export-name = "red/state"
	runtime-third-export-name = "helper"
	frontend/runtime-functions = [red/boot exec/helper]
	block? select frontend/runtime-specs (to word! "red>boot")
	block? select frontend/runtime-specs (to word! "exec>nested>hidden")
]["runtime exports did not use ordinary library resolution and the private Red ABI"]

red-get-count: red-in-count: 0
red-get-spec: red-in-path: red-in-word: none
red-compiler-process-get: func [spec code [block!]][
	red-get-count: red-get-count + 1
	red-get-spec: spec
	remove/part code 2
	insert code 41
	true
]
red-compiler-process-in: func [path word code [block!]][
	red-in-count: red-in-count + 1
	red-in-path: copy path
	red-in-word: word
	remove/part code 3
	insert code 42
	true
]
red-compiler-process-typecheck: func [spec [word! block!]][none]
red-compiler-expand-call: func [body [block!] global? [logic!]][copy []]
empty-directive-ir: frontend/compile/runtime/red load {
	Red/System []
	answer: func [return: [integer!] /local value [integer!]][
		#typecheck answer
		#call []
		value: 42
		value
	]
} 'library [answer "answer"]
assert binary? empty-directive-ir [
	"empty statement directive lowering failed: " mold frontend/last-error
]

red-directive-ir: frontend/compile/red load {
	Red/System []
	get-value: func [return: [integer!]][#get answer]
	in-value: func [return: [integer!]][#in system/catalog/errors script]
} 'glue
assert all [
	binary? red-directive-ir
	red-get-count = 1
	red-in-count = 1
	red-get-spec = 'answer
	red-in-path = to path! [system catalog errors]
	red-in-word = 'script
]["Red-generated directives were not expanded under the Red pass"]

runtime-variadic-ir: frontend/compile/runtime load {
	Red/System []
	pack: func [
		[variadic]
		count [integer!]
		list [int-ptr!]
		return: [integer!]
	][count]
	call-pack: func [return: [integer!]][pack [11 22]]
} 'library [pack "pack"]
assert binary? runtime-variadic-ir [
	"runtime variadic export failed: " mold frontend/last-error
]
runtime-variadic-layout: layout-of runtime-variadic-ir
runtime-pack-id: select frontend/function-ids 'pack
assert (function-word runtime-variadic-ir runtime-variadic-layout runtime-pack-id 12) = 586
	"runtime variadic export lost its packed private ABI"

assert none? frontend/compile/runtime load {
	Red/System []
	answer: func [return: [integer!]][1]
} 'glue [answer "answer"] "runtime exports were accepted by a non-library module"
assert frontend/last-error/code = frontend/ERROR-KIND
	"invalid runtime module kind reported the wrong error class"

assert none? compile-text {
	Red/System []
	answer: func [return: [integer!]][1]
} 'library "a shared library without #export was accepted"
assert frontend/last-error/code = frontend/ERROR-CONTEXT
	"missing library export reported the wrong error class"

assert none? compile-text {
	Red/System []
	answer: func [return: [integer!]][1]
	#export [answer]
} 'glue "an executable accepted #export"
assert frontend/last-error/code = frontend/ERROR-CONTEXT
	"executable #export reported the wrong error class"

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

c-string-pointer-ir: compile-text {
	Red/System []
	identity: func [
		value [pointer! [c-string!]]
		return: [pointer! [c-string!]]
	][value]
} 'user
assert binary? c-string-pointer-ir [
	"pointer! [c-string!] failed: " mold frontend/last-error
]
c-string-pointer-layout: layout-of c-string-pointer-ir
assert all [
	(type-word c-string-pointer-ir c-string-pointer-layout 1 0) = -6
	(type-word c-string-pointer-ir c-string-pointer-layout 1 4) = -13
]["pointer! [c-string!] did not retain its one-byte logical pointee"]

constant-array-ir: compile-text {
	Red/System []
	#enum flags! [first-flag: 1 second-flag: 2]
	values: [(first-flag or second-flag) (second-flag + first-flag * 4)]
	read: func [return: [integer!]][values/1]
} 'user
assert binary? constant-array-ir [
	"constant expressions in literal arrays failed: " mold frontend/last-error
]
constant-array-layout: layout-of constant-array-ir
assert all [
	(initializer-word constant-array-ir constant-array-layout 1 4) = 3
	(initializer-word constant-array-ir constant-array-layout 2 4) = 12
]["literal array constants did not follow left-to-right Red/System evaluation"]

u16-ir: compile-text {
	Red/System []
	wide: func [return: [c-string!]][#u16 "A😀"]
} 'user
assert binary? u16-ir ["#u16 lowering failed: " mold frontend/last-error]
u16-layout: layout-of u16-ir
assert all [
	(function-word u16-ir u16-layout 1 8) = -13
	not none? find u16-ir #{41003DD800DE0000}
]["#u16 did not retain c-string! semantics over terminated UTF-16LE data"]

assert none? compile-text {
	Red/System []
	bad: func [return: [c-string!]][#u16 1]
} 'user "#u16 accepted a non-string argument"
assert frontend/last-error/code = frontend/ERROR-UNSUPPORTED
	"invalid #u16 argument reported the wrong error class"

build-date-source: [
	Red/System []
	build-stamp: func [return: [c-string!]][#build-date]
]
build-date-ir: frontend/compile build-date-source 'user
assert binary? build-date-ir [
	"#build-date lowering failed: " mold frontend/last-error
]
build-date-text: build-date-source/6/1
assert all [
	string? build-date-text
	not empty? build-date-text
	not none? find build-date-ir to binary! build-date-text
]["#build-date was not lowered to the current UTC timestamp string"]

script-marker-ir: compile-text {
	Red/System []
	#script %outer.reds
	marked: func [return: [integer!]][
		(#script %inner.reds 40 #script %expression.reds + 2 #script in-memory)
	]
	#script in-memory
} 'user
assert binary? script-marker-ir [
	"#script source markers failed: " mold frontend/last-error
]
assert script-marker-ir = compile-text {
	Red/System []
	marked: func [return: [integer!]][40 + 2]
} 'user "#script source markers changed the generated IR"

assert none? compile-text {
	Red/System []
	#script 1
	marked: func [][]
} 'user "#script accepted a non-file source"
assert frontend/last-error/code = frontend/ERROR-ARGUMENTS
	"invalid #script source reported the wrong error class"

local-type-change-ir: compile-text {
	Red/System []
	fn: func [/local value][value: 1 value: true]
} 'user
assert binary? local-type-change-ir [
	"frontend rejected backend-owned inferred local compatibility: "
	mold frontend/last-error
]
assert none? find (ops-of local-type-change-ir layout-of local-type-change-ir) 8
	"inferred local type change introduced a frontend CAST"

narrow-ir: compile-text {
	Red/System []
	narrow: func [value [int32!] return: [int8!]][value]
} 'user
assert binary? narrow-ir ["frontend rejected backend-owned integer narrowing"]
narrow-layout: layout-of narrow-ir
assert (ops-of narrow-ir narrow-layout) = [3 4 11]
	"integer narrowing introduced a frontend CAST"

sign-change-ir: compile-text {
	Red/System []
	change-sign: func [value [int8!] return: [uint16!]][value]
} 'user
assert binary? sign-change-ir ["frontend rejected backend-owned sign change"]
sign-change-layout: layout-of sign-change-ir
assert (ops-of sign-change-ir sign-change-layout) = [3 4 11]
	"integer sign change introduced a frontend CAST"

mixed-float-binary-ir: compile-text {
	Red/System []
	add: func [a [float!] b [float32!] return: [float32!]][a + b]
} 'user
assert binary? mixed-float-binary-ir [
	"frontend rejected backend-owned floating legality: " mold frontend/last-error
]
assert (ops-of mixed-float-binary-ir layout-of mixed-float-binary-ir) = [
	3 4 3 4 15 11
]["mixed floating arithmetic did not remain one dense binary operation"]

reverse-mixed-float-ir: compile-text {
	Red/System []
	add: func [a [float32!] b [float!] return: [float32!]][a + b]
} 'user
assert binary? reverse-mixed-float-ir [
	"frontend rejected reverse mixed floating arithmetic: " mold frontend/last-error
]
assert (ops-of reverse-mixed-float-ir layout-of reverse-mixed-float-ir) = [
	3 4 3 4 15 11
]["reverse mixed floating arithmetic did not remain one dense binary operation"]

mixed-float-comparison-ir: compile-text {
	Red/System []
	equal?: func [a [float!] b [float32!] return: [logic!]][a = b]
} 'user
assert binary? mixed-float-comparison-ir [
	"frontend rejected backend-owned float comparison legality: "
	mold frontend/last-error
]
assert (ops-of mixed-float-comparison-ir layout-of mixed-float-comparison-ir) = [
	3 4 3 4 15 11
]["mixed floating comparison did not remain one dense binary operation"]

float32-assignment-ir: compile-text {
	Red/System []
	set-single: func [value [float32!]][value: 1.5]
} 'user
assert binary? float32-assignment-ir [
	"frontend rejected backend-owned float assignment narrowing: "
	mold frontend/last-error
]
assert none? find (ops-of float32-assignment-ir layout-of float32-assignment-ir) 8
	"float assignment narrowing introduced a frontend CAST"

invalid-binary-ir: compile-text {
	Red/System []
	fn: func [return: [integer!]][1 + true]
} 'user
assert binary? invalid-binary-ir [
	"frontend rejected backend-owned binary legality: " mold frontend/last-error
]
assert (ops-of invalid-binary-ir layout-of invalid-binary-ir) = [1 1 15 11]
	"invalid scalar arithmetic did not remain one dense binary operation"

invalid-unary-ir: compile-text {
	Red/System []
	fn: func [value [float!] return: [float!]][not value]
} 'user
assert binary? invalid-unary-ir [
	"frontend rejected backend-owned unary legality: " mold frontend/last-error
]
assert (ops-of invalid-unary-ir layout-of invalid-unary-ir) = [3 4 14 11]
	"invalid scalar NOT did not remain one dense unary operation"

invalid-if-ir: compile-text {
	Red/System []
	fn: func [][if 1 []]
} 'user
assert binary? invalid-if-ir [
	"frontend rejected backend-owned IF predicate: " mold frontend/last-error
]
assert not none? find (ops-of invalid-if-ir layout-of invalid-if-ir) frontend/branch-op
	"invalid IF predicate did not reach native BRANCH validation"

invalid-either-merge-ir: compile-text {
	Red/System []
	fn: func [return: [integer!]][either true [1][false]]
} 'user
assert binary? invalid-either-merge-ir [
	"frontend rejected backend-owned EITHER merge: " mold frontend/last-error
]
assert none? find (ops-of invalid-either-merge-ir
	layout-of invalid-either-merge-ir) frontend/drop-op
	"invalid EITHER merge was hidden by frontend DROP operations"

invalid-case-merge-ir: compile-text {
	Red/System []
	fn: func [return: [integer!]][case [true [1] false [false]]]
} 'user
assert binary? invalid-case-merge-ir [
	"frontend rejected backend-owned CASE merge: " mold frontend/last-error
]
assert none? find (ops-of invalid-case-merge-ir
	layout-of invalid-case-merge-ir) frontend/drop-op
	"invalid CASE merge was hidden by frontend DROP operations"

invalid-switch-selector-ir: compile-text {
	Red/System []
	fn: func [value [logic!]][switch value [1 []]]
} 'user
assert binary? invalid-switch-selector-ir [
	"frontend rejected backend-owned SWITCH selector: " mold frontend/last-error
]
assert not none? find (ops-of invalid-switch-selector-ir
	layout-of invalid-switch-selector-ir) frontend/switch-op
	"invalid SWITCH selector did not reach native SWITCH validation"

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

invalid-exit-ir: compile-text {
	Red/System [] fn: func [return: [integer!]][exit]
} 'user
assert binary? invalid-exit-ir [
	"frontend rejected backend-owned EXIT result: " mold frontend/last-error
]
invalid-exit-layout: layout-of invalid-exit-ir
assert (function-instruction-word invalid-exit-ir invalid-exit-layout 1 1 4) = 0
	"EXIT did not preserve its void RETURN for native validation"

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
assert (function-word use-ir use-layout 1 28) = 4
	"independent USE declarations did not retain distinct frame slots"

subroutine-ir: compile-text {
	Red/System []
	fn: func [return: [integer!] /local value [integer!] step [subroutine!]][
		value: 2
		step
		step
		step: [value: value + 3]
		value
	]
} 'user
assert binary? subroutine-ir [
	"subroutine lowering failed: " mold frontend/last-error
]
subroutine-layout: layout-of subroutine-ir
subroutine-ops: ops-of subroutine-ir subroutine-layout
subroutine-entry: 0
subroutine-main: 0
subroutine-call-target: 0
repeat id function-word subroutine-ir subroutine-layout 1 32 [
	operation: function-instruction-word subroutine-ir subroutine-layout 1 id 0
	case [
		all [
			operation = 27
			(function-instruction-word subroutine-ir subroutine-layout 1 id 4) = 1
		][subroutine-entry: id]
		all [
			operation = 27
			(function-instruction-word subroutine-ir subroutine-layout 1 id 4) = 0
		][subroutine-main: id]
		operation = 28 [
			subroutine-call-target: function-instruction-word
				subroutine-ir subroutine-layout 1 id 4
		]
		true [0]
	]
]
assert all [
	(function-word subroutine-ir subroutine-layout 1 28) = 1
	(first subroutine-ops) = 16
	(op-count subroutine-ops 15) = 1
	(op-count subroutine-ops 27) = 2
	(op-count subroutine-ops 28) = 2
	(op-count subroutine-ops 29) = 1
	subroutine-entry > 0
	subroutine-main > subroutine-entry
	subroutine-call-target = subroutine-entry
]["subroutine body was not emitted once with direct calls and a separate main path"]

subroutine-optional-result-ir: compile-text {
	Red/System []
	stop: func [][]
	fn: func [
		flag [logic!]
		/local result [integer!] step [subroutine!]
	][
		result: 0
		step: [
			case [
				flag [result: 1]
				true [stop]
			]
		]
		step
	]
} 'user
assert binary? subroutine-optional-result-ir [
	"optional subroutine result inference failed: " mold frontend/last-error
]
subroutine-optional-layout: layout-of subroutine-optional-result-ir
subroutine-optional-call: 0
repeat id function-word subroutine-optional-result-ir subroutine-optional-layout 2 32 [
	if (function-instruction-word subroutine-optional-result-ir
		subroutine-optional-layout 2 id 0) = 28 [
		subroutine-optional-call: id
	]
]
assert all [
	subroutine-optional-call > 0
	(function-instruction-word subroutine-optional-result-ir
		subroutine-optional-layout 2 subroutine-optional-call 8) = 0
]["mixed value/void subroutine tail did not infer a void result"]

assert none? compile-text {
	Red/System []
	fn: func [][use [step [subroutine!]][]]
} 'user "USE accepted a subroutine local"
assert frontend/last-error/code = frontend/ERROR-UNSUPPORTED
	"USE subroutine local reported the wrong error class"

separate-use-locals-ir: compile-text {
	Red/System []
	fn: func [][
		use [value [integer!]][]
		use [value [logic!]][]
	]
} 'user
assert binary? separate-use-locals-ir [
	"separate USE contexts rejected independent same-name declarations: "
	mold frontend/last-error
]
separate-use-layout: layout-of separate-use-locals-ir
assert all [
	(function-word separate-use-locals-ir separate-use-layout 1 28) = 2
	(word-at separate-use-locals-ir separate-use-layout/5) = -5
	(word-at separate-use-locals-ir (separate-use-layout/5 + 8)) = -11
]["separate USE declarations reused one frontend frame slot"]

assert none? compile-text {
	Red/System []
	fn: func [return: [integer!] /local step [subroutine!]][
		step: [step]
		step
	]
} 'user "recursive subroutine unexpectedly compiled"
assert frontend/last-error/code = frontend/ERROR-CONTEXT
	"recursive subroutine reported the wrong error class"

assert none? compile-text {
	Red/System []
	fn: func [/local first second [subroutine!]][
		first: [second]
		second: [first]
		first
	]
} 'user "indirectly recursive subroutines unexpectedly compiled"
assert frontend/last-error/code = frontend/ERROR-CONTEXT
	"indirect subroutine recursion reported the wrong error class"

subroutine-inferred-ir: compile-text {
	Red/System []
	fn: func [return: [integer!] /local step [subroutine!] value][
		step: [value: 1]
		step
		value
	]
} 'user
assert binary? subroutine-inferred-ir [
	"a subroutine could not establish an untyped local: " mold frontend/last-error
]

assert none? compile-text {
	Red/System []
	fn: func [return: [integer!] /local step [subroutine!] value][
		value: 1
		step: [value: value * 2]
		step
		value
	]
} 'user "a subroutine read a local typed only by the main path"
assert all [
	frontend/last-error/code = frontend/ERROR-REFERENCE
	not none? find frontend/last-error/message "type declaration missing"
]["cross-boundary inferred local reported the wrong subroutine diagnostic"]

assert none? compile-text {
	Red/System []
	fn: func [
		input [float!]
		return: [integer!]
		/local step [subroutine!] value
	][
		value: as integer! input
		step: [push as integer! value]
		0
	]
} 'user "PUSH read a local typed only by the main path"
assert all [
	frontend/last-error/code = frontend/ERROR-REFERENCE
	not none? find frontend/last-error/message "type declaration missing"
]["nested cross-boundary local read reported the wrong subroutine diagnostic"]

stack-ir: compile-text {
	Red/System []
	roundtrip: func [return: [integer!]][
		push 7 * 6
		pop + 1
	]
} 'user
assert binary? stack-ir ["PUSH/POP lowering failed: " mold frontend/last-error]
stack-layout: layout-of stack-ir
assert all [
	(ops-of stack-ir stack-layout) = [1 1 15 10 10 1 15 11]
	(instruction-word stack-ir stack-layout 4 4) = 2
	(instruction-word stack-ir stack-layout 4 8) = 0
	(instruction-word stack-ir stack-layout 4 12) = 0
	(instruction-word stack-ir stack-layout 5 4) = 3
	(instruction-word stack-ir stack-layout 5 8) = 0
	(instruction-word stack-ir stack-layout 5 12) = 0
]["PUSH/POP did not use the ordinary typed postfix stream"]

log-b-ir: compile-text {
	Red/System []
	bits: func [
		a [byte!] b [int8!] c [uint8!] d [int16!] e [uint16!]
		f [integer!] g [uint32!] h [int64!] i [uint64!]
		return: [integer!]
	][
		log-b a
		log-b b
		log-b c
		log-b d
		log-b e
		log-b f
		log-b g
		log-b h
		log-b i
	]
	precedence: func [return: [integer!]][log-b 4 + 4]
} 'user
assert binary? log-b-ir ["LOG-B lowering failed: " mold frontend/last-error]
log-b-layout: layout-of log-b-ir
log-b-effects: make block! 27
repeat id word-at log-b-ir 20 [
	if (instruction-word log-b-ir log-b-layout id 0) = 10 [
		repend log-b-effects [
			instruction-word log-b-ir log-b-layout id 4
			instruction-word log-b-ir log-b-layout id 8
			instruction-word log-b-ir log-b-layout id 12
		]
	]
]
assert log-b-effects = [
	22 0 -5 22 0 -5 22 0 -5 22 0 -5 22 0 -5
	22 0 -5 22 0 -5 22 0 -5 22 0 -5 22 0 -5
]["LOG-B did not retain one direct native operation for the integer family"]
assert (ops-of log-b-ir log-b-layout) = [
	3 4 10 12 3 4 10 12 3 4 10 12 3 4 10 12 3 4 10 12
	3 4 10 12 3 4 10 12 3 4 10 12 3 4 10 11
	1 1 15 10 11
]["LOG-B did not consume one full prefix argument expression"]

invalid-log-b-ir: compile-text {
	Red/System []
	bad: func [return: [integer!]][log-b true]
} 'user
assert binary? invalid-log-b-ir [
	"frontend rejected backend-owned LOG-B operand: " mold frontend/last-error
]
assert not none? find (ops-of invalid-log-b-ir layout-of invalid-log-b-ir)
	frontend/native-op
	"invalid LOG-B operand did not reach its native consumer"

stack-top-ir: compile-text {
	Red/System []
	top: func [return: [pointer! [integer!]]][system/stack/top]
} 'user
assert binary? stack-top-ir [
	"system/stack/top lowering failed: " mold frontend/last-error
]
stack-top-layout: layout-of stack-top-ir
assert all [
	(ops-of stack-top-ir stack-top-layout) = [10 11]
	(instruction-word stack-top-ir stack-top-layout 1 4) = 1
	(instruction-word stack-top-ir stack-top-layout 1 8) = 0
	(instruction-word stack-top-ir stack-top-layout 1 12) > 0
]["system/stack/top lost its pointer! [integer!] result type"]

stack-system-ir: compile-text {
	Red/System []
	read-frame: func [
		return: [pointer! [integer!]]
	][system/stack/frame]
	align-stack: func [
		return: [pointer! [integer!]]
	][system/stack/align]
	allocate-stack: func [
		slots [integer!]
		return: [pointer! [integer!]]
	][system/stack/allocate slots]
	allocate-zero-stack: func [
		slots [integer!]
		return: [pointer! [integer!]]
	][system/stack/allocate/zero slots]
	release-stack: func [slots [integer!]][system/stack/free slots]
	restore-top: func [
		saved [pointer! [integer!]]
		return: [pointer! [integer!]]
	][system/stack/top: saved]
	restore-frame: func [
		saved [pointer! [integer!]]
		return: [pointer! [integer!]]
	][system/stack/frame: saved]
	save-registers: func [][
		system/stack/push-all
		system/stack/pop-all
	]
} 'user
assert binary? stack-system-ir [
	"system/stack family lowering failed: " mold frontend/last-error
]
stack-system-layout: layout-of stack-system-ir
assert all [
	(ops-of stack-system-ir stack-system-layout) = [
		10 11 10 11
		3 4 10 11 3 4 10 11 3 4 10 11
		3 4 10 11 3 4 10 11 10 10 11
	]
	(instruction-word stack-system-ir stack-system-layout 1 4) = 4
	(instruction-word stack-system-ir stack-system-layout 3 4) = 7
	(instruction-word stack-system-ir stack-system-layout 7 4) = 8
	(instruction-word stack-system-ir stack-system-layout 11 4) = 9
	(instruction-word stack-system-ir stack-system-layout 15 4) = 10
	(instruction-word stack-system-ir stack-system-layout 19 4) = 5
	(instruction-word stack-system-ir stack-system-layout 23 4) = 6
	(instruction-word stack-system-ir stack-system-layout 25 4) = 11
	(instruction-word stack-system-ir stack-system-layout 26 4) = 12
	(instruction-word stack-system-ir stack-system-layout 7 12) > 0
	(instruction-word stack-system-ir stack-system-layout 15 12) = 0
]["system/stack family did not keep its direct typed postfix effects"]

cpu-system-ir: compile-text {
	Red/System []
	current-pc: func [return: [byte-ptr!]][system/pc]
	overflowed?: func [return: [logic!]][system/cpu/overflow?]
	touch-registers: func [
		value [int-ptr!]
		return: [int-ptr!]
	][
		system/cpu/rax: value
		system/cpu/rcx: value
		system/cpu/rdx: value
		system/cpu/rbx: value
		system/cpu/rsp: value
		system/cpu/rbp: value
		system/cpu/rsi: value
		system/cpu/rdi: value
		system/cpu/r8: value
		system/cpu/r9: value
		system/cpu/r10: value
		system/cpu/r11: value
		system/cpu/r12: value
		system/cpu/r13: value
		system/cpu/r14: value
		system/cpu/r15: value
		system/cpu/r15
	]
} 'user
assert binary? cpu-system-ir [
	"system/pc and system/cpu lowering failed: " mold frontend/last-error
]
cpu-system-layout: layout-of cpu-system-ir
cpu-system-ops: ops-of cpu-system-ir cpu-system-layout
cpu-effects: make block! 64
cpu-register-effects: make block! 64
repeat id word-at cpu-system-ir 20 [
	if (instruction-word cpu-system-ir cpu-system-layout id 0) = 10 [
		repend cpu-effects [
			instruction-word cpu-system-ir cpu-system-layout id 4
			instruction-word cpu-system-ir cpu-system-layout id 8
			instruction-word cpu-system-ir cpu-system-layout id 12
		]
		if find [14 15] instruction-word cpu-system-ir cpu-system-layout id 4 [
			append cpu-register-effects
				instruction-word cpu-system-ir cpu-system-layout id 4
			append/only cpu-register-effects
				to string! instruction-bytes cpu-system-ir cpu-system-layout id
		]
	]
]
pc-ref: cpu-effects/3
cpu-ref: function-word cpu-system-ir cpu-system-layout 3 8
expected-effects: make block! 40
foreach name [
	"rax" "rcx" "rdx" "rbx" "rsp" "rbp" "rsi" "rdi"
	"r8" "r9" "r10" "r11" "r12" "r13" "r14" "r15"
][repend expected-effects [15 name]]
repend expected-effects [14 "r15"]
assert all [
	pc-ref > 0
	cpu-ref > 0
	pc-ref <> cpu-ref
	(copy/part cpu-effects 6) = reduce [13 0 pc-ref 16 0 -11]
	(type-word cpu-system-ir cpu-system-layout cpu-ref 0) = -6
	(type-word cpu-system-ir cpu-system-layout cpu-ref 4) = -5
	cpu-register-effects = expected-effects
	(copy/part at cpu-system-ops 5 4) = [3 4 10 12]
]["system/pc and system/cpu did not retain machine-independent register effects"]

assert none? compile-text {
	Red/System []
	fn: func [][system/pc: null]
} 'user "system/pc accepted assignment"
assert frontend/last-error/code = frontend/ERROR-REFERENCE
	"system/pc assignment reported the wrong error class"

assert none? compile-text {
	Red/System []
	fn: func [][system/cpu/overflow?: true]
} 'user "system/cpu/overflow? accepted assignment"
assert frontend/last-error/code = frontend/ERROR-REFERENCE
	"system/cpu/overflow? assignment reported the wrong error class"

unknown-cpu-ir: compile-text {
	Red/System []
	fn: func [][system/cpu/r16]
} 'user
assert binary? unknown-cpu-ir
	"the machine-independent frontend rejected a target register name"
unknown-cpu-layout: layout-of unknown-cpu-ir
assert (to string! instruction-bytes unknown-cpu-ir unknown-cpu-layout 1) = "r16"
	"the machine-independent frontend did not retain the register name"

invalid-cpu-value-ir: compile-text {
	Red/System []
	fn: func [][system/cpu/rax: 1]
} 'user
assert binary? invalid-cpu-value-ir
	"CPU register value checking was not transferred to native codegen"

overflow-ir: compile-text {
	Red/System []
	overflows-internally: func [return: [integer!]][2147483647 + 1]
	checked: func [
		value count [integer!]
		return: [logic!]
		/local result [integer!] flag [logic!]
	][
		flag: overflow? [
			result: value + (1 + 2)
			result: result << 3
			result: result << count
			result: result / -1
			result: overflows-internally
		]
		flag
	]
} 'user
assert binary? overflow-ir [
	"overflow? lowering failed: " mold frontend/last-error
]
overflow-layout: layout-of overflow-ir
overflow-anchor: 0
overflow-anchor-count: 0
checked-count: function-word overflow-ir overflow-layout 2 32
repeat id checked-count [
	if (function-instruction-word overflow-ir overflow-layout 2 id 0) = 23 [
		overflow-anchor: id
		overflow-anchor-count: overflow-anchor-count + 1
	]
]
assert overflow-anchor-count = 1
	"overflow? did not lower to one direct lexical scope anchor"
assert all [
	(function-instruction-word overflow-ir overflow-layout 1 3 0) = 15
	(function-instruction-word overflow-ir overflow-layout 1 3 8) = 0
	(function-instruction-word overflow-ir overflow-layout 1 3 12) = 0
]["ordinary called function math was marked as caller overflow work"]

tracked-adds: 0
tracked-divisions: 0
literal-shifts: 0
runtime-shifts: 0
repeat id checked-count [
	if (function-instruction-word overflow-ir overflow-layout 2 id 0) = 15 [
		operation: function-instruction-word overflow-ir overflow-layout 2 id 4
		anchor: function-instruction-word overflow-ir overflow-layout 2 id 8
		data: function-instruction-word overflow-ir overflow-layout 2 id 12
		case [
			operation = 1 [
				if all [anchor = overflow-anchor data = 0][
					tracked-adds: tracked-adds + 1
				]
			]
			operation = 4 [
				if all [anchor = overflow-anchor data = 0][
					tracked-divisions: tracked-divisions + 1
				]
			]
			operation = 7 [
				either all [anchor = overflow-anchor data = 3][
					literal-shifts: literal-shifts + 1
				][
					if all [anchor = 0 data = 0][
						runtime-shifts: runtime-shifts + 1
					]
				]
			]
			true [0]
		]
	]
]
overflow-target: function-instruction-word overflow-ir overflow-layout 2
	overflow-anchor 4
assert all [
	tracked-adds = 2
	tracked-divisions = 1
	literal-shifts = 1
	runtime-shifts = 1
	overflow-target > overflow-anchor
	overflow-target <= checked-count
	(function-instruction-word overflow-ir overflow-layout 2 overflow-target 0) = 1
	(function-instruction-word overflow-ir overflow-layout 2 overflow-target 4) = -11
	(function-instruction-word overflow-ir overflow-layout 2 overflow-target 8) = 1
]["overflow? did not retain direct typed operation and true-edge metadata"]

nested-overflow-ir: compile-text {
	Red/System []
	fn: func [
		return: [logic!]
		/local value [integer!] inner? [logic!]
	][
		overflow? [
			inner?: overflow? [value: 2147483647 + 1]
			value: value + 0
		]
	]
} 'user
assert binary? nested-overflow-ir [
	"nested overflow? lowering failed: " mold frontend/last-error
]
nested-layout: layout-of nested-overflow-ir
nested-anchors: make block! 2
nested-binaries: make block! 2
repeat id function-word nested-overflow-ir nested-layout 1 32 [
	operation: function-instruction-word nested-overflow-ir nested-layout 1 id 0
	case [
		operation = 23 [append nested-anchors id]
		operation = 15 [
			append nested-binaries function-instruction-word
				nested-overflow-ir nested-layout 1 id 8
		]
		true [0]
	]
]
assert all [
	(length? nested-anchors) = 2
	nested-binaries = reduce [nested-anchors/2 nested-anchors/1]
]["nested overflow? scopes were not kept lexically independent"]

subroutine-overflow-ir: compile-text {
	Red/System []
	fn: func [
		return: [logic!]
		/local value [integer!] step [subroutine!]
	][
		step: [value: 2147483647 + 1]
		overflow? [step]
	]
} 'user
assert binary? subroutine-overflow-ir [
	"subroutine overflow? isolation failed: " mold frontend/last-error
]
subroutine-overflow-layout: layout-of subroutine-overflow-ir
subroutine-anchor: 0
subroutine-binary: 0
repeat id function-word subroutine-overflow-ir subroutine-overflow-layout 1 32 [
	operation: function-instruction-word subroutine-overflow-ir
		subroutine-overflow-layout 1 id 0
	case [
		operation = 23 [subroutine-anchor: id]
		operation = 15 [subroutine-binary: id]
		true [0]
	]
]
assert all [
	subroutine-anchor > 0
	(function-instruction-word subroutine-overflow-ir subroutine-overflow-layout
		1 subroutine-anchor 4) = 0
	subroutine-binary > 0
	(function-instruction-word subroutine-overflow-ir subroutine-overflow-layout
		1 subroutine-binary 8) = 0
]["expanded subroutine math leaked into its caller's overflow? scope"]

untracked-overflow-ir: compile-text {
	Red/System []
	fn: func [
		count [integer!]
		return: [logic!]
		/local value [integer!] real [float!]
	][
		overflow? [
			real: 1.0 + 2.0
			value: value << count
		]
	]
} 'user
assert binary? untracked-overflow-ir [
	"untracked overflow? lowering failed: " mold frontend/last-error
]
untracked-layout: layout-of untracked-overflow-ir
untracked-anchor: 0
untracked-binaries: 0
repeat id function-word untracked-overflow-ir untracked-layout 1 32 [
	operation: function-instruction-word untracked-overflow-ir
		untracked-layout 1 id 0
	case [
		operation = 23 [untracked-anchor: id]
		operation = 15 [
			untracked-binaries: untracked-binaries + 1
			assert all [
				(function-instruction-word untracked-overflow-ir untracked-layout
					1 id 8) = 0
				(function-instruction-word untracked-overflow-ir untracked-layout
					1 id 12) = 0
			]["runtime shift or float math received overflow metadata"]
		]
		true [0]
	]
]
assert all [
	untracked-anchor > 0
	untracked-binaries = 2
	(function-instruction-word untracked-overflow-ir untracked-layout
		1 untracked-anchor 4) = 0
]["an overflow? body without tracked math did not remain a direct false result"]

assert none? compile-text {
	Red/System []
	fn: func [][overflow? 1]
} 'user "overflow? accepted a non-block body"
assert frontend/last-error/code = frontend/ERROR-UNSUPPORTED
	"invalid overflow? body reported the wrong error class"

assert none? compile-text {
	Red/System []
	fn: func [][overflow?]
} 'user "overflow? accepted a missing body"
assert frontend/last-error/code = frontend/ERROR-UNSUPPORTED
	"missing overflow? body reported the wrong error class"

exception-ir: compile-text {
	Red/System []
	fn: func [return: [integer!]][
		system/thrown: 0
		catch 5 [throw 1]
		system/thrown
	]
} 'user
assert binary? exception-ir ["exception lowering failed: " mold frontend/last-error]
exception-layout: layout-of exception-ir
catch-index: 0
end-catch-index: 0
throw-index: 0
repeat id function-word exception-ir exception-layout 1 32 [
	operation: function-instruction-word exception-ir exception-layout 1 id 0
	case [
		operation = 24 [catch-index: id]
		operation = 25 [end-catch-index: id]
		operation = 26 [throw-index: id]
		true [0]
	]
]
assert all [
	(word-at exception-ir 24) = 1
	(global-word exception-ir exception-layout 1 8) = -5
	catch-index > 0
	end-catch-index > catch-index
	throw-index > catch-index
	throw-index < end-catch-index
	(function-instruction-word exception-ir exception-layout
		1 catch-index 4) = end-catch-index
	(function-instruction-word exception-ir exception-layout 1 catch-index 8) = 1
	(function-instruction-word exception-ir exception-layout
		1 end-catch-index 4) = catch-index
	(function-instruction-word exception-ir exception-layout 1 end-catch-index 8) = 1
	(function-instruction-word exception-ir exception-layout 1 throw-index 4) = 0
	(function-instruction-word exception-ir exception-layout
		1 (throw-index - 1) 0) = 3
]["catch/throw did not retain its value/place ownership boundary"]

shared-exception-ir: compile-text {
	Red/System []
	system!: alias struct! [thrown [integer!]]
	#import [
		"runtime.dll" stdcall [
			system: "system" [system!]
		]
	]
	fn: func [return: [integer!]][
		system/thrown: 0
		catch 5 [throw 1]
		system/thrown
	]
} 'user
assert binary? shared-exception-ir [
	"shared exception lowering failed: " mold frontend/last-error
]
shared-exception-layout: layout-of shared-exception-ir
shared-import-addresses: 0
shared-global-addresses: 0
shared-thrown-members: 0
repeat id function-word shared-exception-ir shared-exception-layout 1 32 [
	operation: function-instruction-word shared-exception-ir
		shared-exception-layout 1 id 0
	if operation = 3 [
		case [
			(function-instruction-word shared-exception-ir
				shared-exception-layout 1 id 4) = 3 [
				shared-import-addresses: shared-import-addresses + 1
			]
			(function-instruction-word shared-exception-ir
				shared-exception-layout 1 id 4) = 2 [
				shared-global-addresses: shared-global-addresses + 1
			]
			true [0]
		]
	]
	if operation = 6 [shared-thrown-members: shared-thrown-members + 1]
]
assert all [
	(word-at shared-exception-ir 12) = 1
	(word-at shared-exception-ir 24) = 0
	shared-import-addresses = 3
	shared-global-addresses = 0
	shared-thrown-members = 3
]["imported system/thrown was not used as the exception state"]

owned-exception-ir: compile-text {
	Red/System []
	system!: alias struct! [thrown [integer!]]
	system: declare system!
	fn: func [return: [integer!]][
		system/thrown: 0
		catch 5 [throw 1]
		system/thrown
	]
} 'user
assert binary? owned-exception-ir [
	"owned exception lowering failed: " mold frontend/last-error
]
owned-exception-layout: layout-of owned-exception-ir
owned-system-addresses: 0
owned-thrown-members: 0
repeat id function-word owned-exception-ir owned-exception-layout 1 32 [
	operation: function-instruction-word owned-exception-ir
		owned-exception-layout 1 id 0
	if all [
		operation = 3
		(function-instruction-word owned-exception-ir
			owned-exception-layout 1 id 4) = 2
		(function-instruction-word owned-exception-ir
			owned-exception-layout 1 id 8) = 1
	][owned-system-addresses: owned-system-addresses + 1]
	if operation = 6 [owned-thrown-members: owned-thrown-members + 1]
]
assert all [
	(word-at owned-exception-ir 24) = 2
	owned-system-addresses = 3
	owned-thrown-members = 3
]["runtime-owned system/thrown gained a hidden duplicate global"]

catch-function-ir: compile-text {
	Red/System []
	raiser: func [][throw 7]
	guard: func [[catch]][raiser]
} 'user
assert binary? catch-function-ir [
	"catch function lowering failed: " mold frontend/last-error
]
catch-function-layout: layout-of catch-function-ir
assert all [
	((function-word catch-function-ir catch-function-layout 2 12) and 256) = 256
	((function-word catch-function-ir catch-function-layout 2 12) and 1024) = 0
	(function-ops-of catch-function-ir catch-function-layout 2) = [7 11]
	(word-at catch-function-ir 24) = 1
	not none? find ops-of catch-function-ir catch-function-layout 26
]["a catch function did not resume after a throwing call"]

no-return-ir: compile-text {
	Red/System []
	choose: func [
		flag [logic!]
		return: [integer!]
	][
		either flag [1][abort]
	]
	abort: func [][raiser]
	raiser: func [][throw 7]
	finish: func [][exit]
	answer: func [return: [integer!]][return 1]
} 'user
assert binary? no-return-ir [
	"no-return dependency lowering failed: " mold frontend/last-error
]
no-return-layout: layout-of no-return-ir
assert all [
	((function-word no-return-ir no-return-layout 1 12) and 1024) = 0
	((function-word no-return-ir no-return-layout 2 12) and 1024) = 1024
	((function-word no-return-ir no-return-layout 3 12) and 1024) = 1024
	((function-word no-return-ir no-return-layout 4 12) and 1024) = 0
	((function-word no-return-ir no-return-layout 5 12) and 1024) = 0
]["no-return inference did not distinguish unwinding from normal returns"]

stopped-argument-ir: compile-text {
	Red/System []
	typed-value!: alias struct! [
		type [integer!]
		_align0 [integer!]
		value [int-ptr!]
		_padding [integer!]
		_align1 [integer!]
	]
	callback!: alias function! [value [integer!]]
	stop: func [return: [integer!]][assert false]
	take: func [value [integer!]][]
	take-two: func [left [integer!] right [integer!]][]
	sum: func [[infix] left [integer!] right [integer!] return: [integer!]][left]
	collect: func [[variadic] count [integer!] list [int-ptr!]][]
	typed-sink: func [[typed] count [integer!] list [typed-value!]][]
	custom-sink: func [[custom] return: [integer!]][0]
	fixed-stop: func [][take stop]
	multi-stop: func [][take-two stop 1]
	infix-stop: func [][stop sum 1]
	variadic-stop: func [][collect [stop 1]]
	typed-stop: func [][typed-sink [stop 1]]
	custom-stop: func [][custom-sink stop]
	indirect-stop: func [callback [callback!]][callback stop]
	binary-left-stop: func [][take stop + 1]
	binary-right-stop: func [][take 1 + stop]
	not-stop: func [][take not stop]
	infix-chain-stop: func [][take stop sum 1 + 2]
	cast-stop: func [][take as integer! stop]
} 'user
assert binary? stopped-argument-ir [
	"terminating call argument did not propagate: " mold frontend/last-error
]
stopped-argument-ops: ops-of stopped-argument-ir layout-of stopped-argument-ir
assert all [
	(op-count stopped-argument-ops frontend/call-op) = 12
	(op-count stopped-argument-ops frontend/fail-op) = 8
]["a call survived its terminating argument"]
stopped-argument-layout: layout-of stopped-argument-ir
assert all [
	(function-ops-of stopped-argument-ir stopped-argument-layout 8) = [7]
	(function-ops-of stopped-argument-ir stopped-argument-layout 9) = [7 1 19]
	(function-ops-of stopped-argument-ir stopped-argument-layout 10) = [7 1 19]
	(function-ops-of stopped-argument-ir stopped-argument-layout 11) = [7 1 19]
	(function-ops-of stopped-argument-ir stopped-argument-layout 12) = [7 1 19]
	(function-ops-of stopped-argument-ir stopped-argument-layout 13) = [7]
	(function-ops-of stopped-argument-ir stopped-argument-layout 15) = [7 1 19]
	(function-ops-of stopped-argument-ir stopped-argument-layout 16) = [1 7]
	(function-ops-of stopped-argument-ir stopped-argument-layout 17) = [7]
	(function-ops-of stopped-argument-ir stopped-argument-layout 18) = [7 1 19 1 19]
	(function-ops-of stopped-argument-ir stopped-argument-layout 19) = [7]
]["terminating expression state was not sticky through its consumer"]

nested-catch-ir: compile-text {
	Red/System []
	fn: func [][catch 5 [catch 2 [throw 1]]]
} 'user
assert binary? nested-catch-ir [
	"nested catch lowering failed: " mold frontend/last-error
]
nested-catch-layout: layout-of nested-catch-ir
open-levels: make block! 4
close-levels: make block! 4
repeat id function-word nested-catch-ir nested-catch-layout 1 32 [
	operation: function-instruction-word nested-catch-ir nested-catch-layout 1 id 0
	case [
		operation = 24 [
			append open-levels function-instruction-word nested-catch-ir
				nested-catch-layout 1 id 8
		]
		operation = 25 [
			append close-levels function-instruction-word nested-catch-ir
				nested-catch-layout 1 id 8
		]
		true [0]
	]
]
assert all [open-levels = [1 2] close-levels = [2 1]][
	"nested catch levels did not follow lexical nesting"
]

catch-jump-ir: compile-text {
	Red/System []
	fn: func [][loop 1 [catch 5 [catch 2 [break]]]]
} 'user
assert binary? catch-jump-ir [
	"catch control exit lowering failed: " mold frontend/last-error
]
catch-jump-layout: layout-of catch-jump-ir
catch-unwind: 0
repeat id word-at catch-jump-ir 20 [
	if all [
		(instruction-word catch-jump-ir catch-jump-layout id 0) = 16
		(instruction-word catch-jump-ir catch-jump-layout id 12) = 2
	][catch-unwind: catch-unwind + 1]
]
assert catch-unwind = 1 "BREAK did not carry its two exited catch records"

global-catch-ir: compile-text {
	Red/System []
	catch 3 [throw 1]
} 'glue
assert all [
	binary? global-catch-ir
	not none? find ops-of global-catch-ir layout-of global-catch-ir 24
	not none? find ops-of global-catch-ir layout-of global-catch-ir 26
]["global catch/throw did not lower inside the executable module function"]

invalid-catch-filter-ir: compile-text {
	Red/System []
	fn: func [][catch true []]
} 'user
assert binary? invalid-catch-filter-ir [
	"frontend rejected backend-owned CATCH filter: " mold frontend/last-error
]
assert not none? find (ops-of invalid-catch-filter-ir
	layout-of invalid-catch-filter-ir) frontend/catch-op
	"invalid CATCH filter did not reach native validation"

invalid-throw-id-ir: compile-text {
	Red/System []
	fn: func [][throw true]
} 'user
assert binary? invalid-throw-id-ir [
	"frontend rejected backend-owned THROW ID: " mold frontend/last-error
]
invalid-throw-ops: ops-of invalid-throw-id-ir layout-of invalid-throw-id-ir
assert all [
	not none? find invalid-throw-ops frontend/throw-op
	none? find invalid-throw-ops frontend/set-op
]["invalid THROW ID did not reach its direct native consumer"]

global-throw-ir: compile-text {
	Red/System []
	throw 1
} 'glue
assert all [
	binary? global-throw-ir
	not none? find ops-of global-throw-ir layout-of global-throw-ir 26
]["uncaught global THROW did not lower for the root exception barrier"]

assert none? compile-text {
	Red/System []
	fn: func [[catch cdecl]][]
} 'user "catch was combined with a calling convention"
assert frontend/last-error/code = frontend/ERROR-UNSUPPORTED
	"catch attribute conflict reported the wrong error class"

invalid-thrown-set-ir: compile-text {
	Red/System []
	fn: func [][system/thrown: true]
} 'user
assert binary? invalid-thrown-set-ir [
	"frontend rejected backend-owned system/thrown SET: " mold frontend/last-error
]
assert not none? find (ops-of invalid-thrown-set-ir
	layout-of invalid-thrown-set-ir) frontend/set-op
	"invalid system/thrown source did not reach native SET"

atomic-ir: compile-text {
	Red/System []
	atomic-ptr!: alias pointer! [integer!]
	operations: func [
		value [atomic-ptr!]
		return: [integer!]
	][
		system/atomic/fence
		system/atomic/store value 1
		system/atomic/load value
		system/atomic/cas value 1 2
		system/atomic/add value 1
		system/atomic/sub value 1
		system/atomic/or value 1
		system/atomic/xor value 1
		system/atomic/and value 1
		system/atomic/add/old value 1
		system/atomic/sub/old value 1
		system/atomic/or/old value 1
		system/atomic/xor/old value 1
		system/atomic/and/old value 1
		system/atomic/load value
	]
} 'user
assert binary? atomic-ir [
	"system/atomic lowering failed: " mold frontend/last-error
]
atomic-layout: layout-of atomic-ir
atomic-effects: make block! 48
repeat id word-at atomic-ir 20 [
	if (instruction-word atomic-ir atomic-layout id 0) = 10 [
		repend atomic-effects [
			instruction-word atomic-ir atomic-layout id 4
			instruction-word atomic-ir atomic-layout id 8
			instruction-word atomic-ir atomic-layout id 12
		]
	]
]
assert atomic-effects = [
	17 0 0
	19 0 0
	18 0 -5
	20 0 -11
	21 1 -5 21 2 -5 21 3 -5 21 4 -5 21 5 -5
	21 9 -5 21 10 -5 21 11 -5 21 12 -5 21 13 -5
	18 0 -5
]["system/atomic did not retain one direct typed native family"]

invalid-atomic-load-ir: compile-text {
	Red/System []
	fn: func [value [pointer! [byte!]]][system/atomic/load value]
} 'user
assert binary? invalid-atomic-load-ir [
	"frontend rejected backend-owned atomic LOAD pointer: " mold frontend/last-error
]
assert not none? find (ops-of invalid-atomic-load-ir
	layout-of invalid-atomic-load-ir) frontend/native-op
	"invalid atomic LOAD pointer did not reach native validation"

invalid-atomic-store-ir: compile-text {
	Red/System []
	fn: func [value [pointer! [integer!]]][system/atomic/store value true]
} 'user
assert binary? invalid-atomic-store-ir [
	"frontend rejected backend-owned atomic STORE value: " mold frontend/last-error
]
assert not none? find (ops-of invalid-atomic-store-ir
	layout-of invalid-atomic-store-ir) frontend/native-op
	"invalid atomic STORE value did not reach native validation"

invalid-atomic-cas-ir: compile-text {
	Red/System []
	fn: func [value [pointer! [integer!]]][system/atomic/cas value false 1]
} 'user
assert binary? invalid-atomic-cas-ir [
	"frontend rejected backend-owned atomic CAS value: " mold frontend/last-error
]
assert not none? find (ops-of invalid-atomic-cas-ir
	layout-of invalid-atomic-cas-ir) frontend/native-op
	"invalid atomic CAS value did not reach native validation"

assert none? compile-text {
	Red/System []
	fn: func [value [pointer! [integer!]]][system/atomic/multiply value 2]
} 'user "system/atomic accepted an unknown operation"
assert frontend/last-error/code = frontend/ERROR-REFERENCE
	"unknown atomic operation reported the wrong error class"

assert none? compile-text {
	Red/System []
	fn: func [value [pointer! [integer!]]][system/atomic/add/new value 2]
} 'user "system/atomic accepted an unknown refinement"
assert frontend/last-error/code = frontend/ERROR-REFERENCE
	"unknown atomic refinement reported the wrong error class"

invalid-stack-allocate-ir: compile-text {
	Red/System []
	fn: func [return: [pointer! [integer!]]][
		system/stack/allocate true
	]
} 'user
assert binary? invalid-stack-allocate-ir [
	"frontend rejected backend-owned stack ALLOCATE value: " mold frontend/last-error
]
assert not none? find (ops-of invalid-stack-allocate-ir
	layout-of invalid-stack-allocate-ir) frontend/native-op
	"invalid stack ALLOCATE value did not reach native validation"

invalid-stack-free-ir: compile-text {
	Red/System []
	fn: func [][system/stack/free as int64! 1]
} 'user
assert binary? invalid-stack-free-ir [
	"frontend rejected backend-owned stack FREE value: " mold frontend/last-error
]
assert not none? find (ops-of invalid-stack-free-ir
	layout-of invalid-stack-free-ir) frontend/native-op
	"invalid stack FREE value did not reach native validation"

assert none? compile-text {
	Red/System []
	sink: func [][]
	fn: func [value [pointer! [integer!]]][system/atomic/store value sink]
} 'user "system/atomic accepted an argument without a value"
assert frontend/last-error/message = "system/atomic argument is missing a value"
	"atomic argument presence was not retained as frontend structure"

stopped-native-ir: compile-text {
	Red/System []
	stop-int: func [return: [integer!]][assert false]
	stop-pointer: func [return: [pointer! [integer!]]][assert false]
	atomic-load-stop: func [][system/atomic/load stop-pointer]
	atomic-store-pointer-stop: func [][system/atomic/store stop-pointer 1]
	atomic-store-value-stop: func [value [pointer! [integer!]]][
		system/atomic/store value stop-int
	]
	atomic-cas-check-stop: func [value [pointer! [integer!]]][
		system/atomic/cas value stop-int 1
	]
	atomic-cas-new-stop: func [value [pointer! [integer!]]][
		system/atomic/cas value 1 stop-int
	]
	stack-allocate-stop: func [][system/stack/allocate stop-int]
	stack-free-stop: func [][system/stack/free stop-int]
	push-stop: func [][push stop-int]
	log-b-stop: func [return: [integer!]][log-b stop-int]
	catch-stop: func [][catch stop-int []]
	throw-stop: func [][throw stop-int]
	thrown-stop: func [][system/thrown: stop-int]
	cpu-stop: func [][system/cpu/rcx: stop-pointer]
} 'user
assert binary? stopped-native-ir [
	"terminating native operand did not propagate: " mold frontend/last-error
]
stopped-native-ops: ops-of stopped-native-ir layout-of stopped-native-ir
assert all [
	not none? find stopped-native-ops frontend/call-op
	none? find stopped-native-ops frontend/native-op
	none? find stopped-native-ops frontend/catch-op
	none? find stopped-native-ops frontend/throw-op
	none? find stopped-native-ops frontend/set-op
]["a native consumer survived its terminating operand"]

assert none? compile-text {
	Red/System []
	fn: func [][system/stack/align: null]
} 'user "system/stack/align accepted assignment"
assert frontend/last-error/code = frontend/ERROR-REFERENCE
	"invalid stack assignment reported the wrong error class"

invalid-stack-top-ir: compile-text {
	Red/System []
	fn: func [][system/stack/top: 1]
} 'user
assert binary? invalid-stack-top-ir [
	"frontend rejected backend-owned stack pointer compatibility: "
	mold frontend/last-error
]
assert none? find (ops-of invalid-stack-top-ir layout-of invalid-stack-top-ir) 8
	"invalid stack pointer assignment introduced a frontend CAST"

assert none? compile-text {
	Red/System []
	fn: func [][system/stack/allocate/clear 1]
} 'user "system/stack accepted an unknown allocation refinement"
assert frontend/last-error/code = frontend/ERROR-REFERENCE
	"invalid stack refinement reported the wrong error class"

assert none? compile-text {
	Red/System []
	sink: func [][]
	fn: func [][push sink]
} 'user "PUSH accepted an expression without a value"
assert frontend/last-error/code = frontend/ERROR-REFERENCE
	"valueless PUSH reported the wrong error class"

custom-ir: compile-text {
	Red/System []
	target: func [[custom] return: [integer!]][41]
	caller: func [return: [integer!]][target 0]
} 'user
assert binary? custom-ir ["custom call lowering failed: " mold frontend/last-error]
custom-layout: layout-of custom-ir
assert all [
	(function-word custom-ir custom-layout 1 12) = 32
	(ops-of custom-ir custom-layout) = [1 11 1 7 11]
	(instruction-word custom-ir custom-layout 4 4) = 1
	(instruction-word custom-ir custom-layout 4 8) = 1
	(instruction-word custom-ir custom-layout 4 12) = -5
]["custom count was not an ordinary CALL operand"]

dynamic-custom-ir: compile-text {
	Red/System []
	count: func [return: [integer!]][2]
	target: func [[custom] return: [integer!]][41]
	caller: func [return: [integer!]][target count]
} 'user
assert binary? dynamic-custom-ir [
	"dynamic custom count lowering failed: " mold frontend/last-error
]
dynamic-custom-layout: layout-of dynamic-custom-ir
assert all [
	(ops-of dynamic-custom-ir dynamic-custom-layout) = [1 11 1 11 7 7 11]
	(instruction-word dynamic-custom-ir dynamic-custom-layout 5 4) = 1
	(instruction-word dynamic-custom-ir dynamic-custom-layout 5 8) = 0
	(instruction-word dynamic-custom-ir dynamic-custom-layout 6 4) = 2
	(instruction-word dynamic-custom-ir dynamic-custom-layout 6 8) = 1
]["dynamic custom count bypassed ordinary expression lowering"]

indirect-custom-ir: compile-text {
	Red/System []
	custom!: alias function! [[custom] return: [integer!]]
	target: func [value [integer!] return: [integer!]][value]
	caller: func [return: [integer!] /local fn [custom!]][
		fn: as custom! :target
		push 7
		fn 1
	]
} 'user
assert binary? indirect-custom-ir [
	"indirect custom call lowering failed: " mold frontend/last-error
]
indirect-custom-layout: layout-of indirect-custom-ir
assert all [
	(instruction-word indirect-custom-ir indirect-custom-layout
		((word-at indirect-custom-ir 20) - 1) 0) = 7
	(instruction-word indirect-custom-ir indirect-custom-layout
		((word-at indirect-custom-ir 20) - 1) 4) = 0
	(instruction-word indirect-custom-ir indirect-custom-layout
		((word-at indirect-custom-ir 20) - 1) 8) = 1
	(instruction-word indirect-custom-ir indirect-custom-layout
		((word-at indirect-custom-ir 20) - 1) 12) > 0
]["indirect custom call lost its function signature or count operand"]

invalid-custom-count-ir: compile-text {
	Red/System []
	target: func [[custom] return: [integer!]][41]
	caller: func [return: [integer!]][target true]
} 'user
assert binary? invalid-custom-count-ir [
	"frontend rejected backend-owned custom count type: " mold frontend/last-error
]
assert none? find (ops-of invalid-custom-count-ir
	layout-of invalid-custom-count-ir) frontend/cast-op
	"invalid custom count introduced a frontend CAST"

diagnostic-ir: compile-text {
	Red/System []
	value: as integer! 1
	identity: func [n [integer!] return: [integer!]][as integer! n]
} 'user
assert binary? diagnostic-ir [
	"same-type casts failed: " mold frontend/last-error
]
assert all [
	(length? frontend/warnings) = 2
	frontend/warnings/1 =
		"type casting from integer! to integer! is not necessary"
	frontend/warnings/2 =
		"type casting from integer! to integer! is not necessary"
]["same-type casts did not report canonical warnings"]

invalid-static-function-cast-ir: compile-text {
	Red/System []
	foo: func [][]
	bad: as byte! :foo
} 'user
assert binary? invalid-static-function-cast-ir [
	"frontend rejected backend-owned static address cast: " mold frontend/last-error
]
invalid-static-function-layout: layout-of invalid-static-function-cast-ir
assert all [
	(initializer-word invalid-static-function-cast-ir
		invalid-static-function-layout 1 0) = 2
	(initializer-word invalid-static-function-cast-ir
		invalid-static-function-layout 1 12) > 0
]["static function cast did not retain its source type for native validation"]

invalid-float-cast-ir: compile-text {
	Red/System []
	bad: func [return: [byte!]][as byte! 1.0]
} 'user
assert binary? invalid-float-cast-ir [
	"frontend rejected backend-owned float cast legality: " mold frontend/last-error
]
assert not none? find (ops-of invalid-float-cast-ir
	layout-of invalid-float-cast-ir) frontend/cast-op
	"invalid float cast did not reach native codegen"

invalid-static-keep-cast-ir: compile-text {
	Red/System []
	bad: as float! keep 1
} 'glue
assert binary? invalid-static-keep-cast-ir [
	"frontend rejected backend-owned static keep cast: " mold frontend/last-error
]
assert not none? find (ops-of invalid-static-keep-cast-ir
	layout-of invalid-static-keep-cast-ir) frontend/cast-op
	"invalid static keep cast was folded before native validation"

invalid-string-cast-ir: compile-text {
	Red/System []
	bad: func [return: [byte!]][as byte! "text"]
} 'user
assert binary? invalid-string-cast-ir [
	"frontend rejected backend-owned c-string cast legality: " mold frontend/last-error
]
assert not none? find (ops-of invalid-string-cast-ir
	layout-of invalid-string-cast-ir) frontend/cast-op
	"invalid c-string cast did not reach native codegen"

dynamic-invalid-cast-ir: compile-text {
	Red/System []
	p: declare pointer! [integer!]
	bad-pointer: func [return: [byte!]][as byte! p]
	bad-float: func [value [float!] return: [byte!]][as byte! value]
	bad-string: func [return: [byte!]][as byte! "text"]
	bad-binary: func [return: [byte!]][as byte! #{0102}]
} 'user
assert binary? dynamic-invalid-cast-ir [
	"frontend rejected backend-owned dynamic cast legality: " mold frontend/last-error
]
assert (op-count (ops-of dynamic-invalid-cast-ir layout-of dynamic-invalid-cast-ir)
	frontend/cast-op) = 4
	"dynamic invalid casts did not retain one dense CAST each"

invalid-control-predicates-ir: compile-text {
	Red/System []
	bad-case: func [][case [1 [] true []]]
	bad-while: func [][while [1][]]
	bad-until: func [][until [1]]
	bad-loop: func [][loop true []]
	bad-all: func [return: [logic!]][all [1 true]]
	bad-any: func [return: [logic!]][any [1 false]]
} 'user
assert binary? invalid-control-predicates-ir [
	"frontend rejected backend-owned control predicates: " mold frontend/last-error
]
invalid-control-ops: ops-of invalid-control-predicates-ir
	layout-of invalid-control-predicates-ir
assert all [
	(op-count invalid-control-ops frontend/branch-op) >= 5
	not none? find invalid-control-ops frontend/set-op
]["invalid control predicates did not retain their native consumers"]

invalid-final-conditions-ir: compile-text {
	Red/System []
	bad-all: func [return: [logic!]][all [true 1]]
	bad-any: func [return: [logic!]][any [false 1]]
} 'user
assert binary? invalid-final-conditions-ir [
	"frontend rejected backend-owned final ANY/ALL predicates: "
	mold frontend/last-error
]
assert (op-count (ops-of invalid-final-conditions-ir
	layout-of invalid-final-conditions-ir) frontend/branch-op) = 4
	"final ANY/ALL predicates did not reach native BRANCH validation"

assert none? compile-text {Red/System [] return} 'user
	"RETURN was accepted outside a function"
assert frontend/last-error/message =
	"return is not allowed outside of a function"
	"RETURN outside a function did not report the canonical error"

assert none? compile-text {Red/System [] exit} 'user
	"EXIT was accepted outside a function"
assert frontend/last-error/message = "exit is not allowed outside of a function"
	"EXIT outside a function did not report the canonical error"

assert none? compile-text {
	Red/System []
	foo: func [][return]
} 'user "RETURN was accepted in a function without a result"
assert frontend/last-error/message =
	"RETURN keyword used without return: declaration in foo"
	"void RETURN did not report the canonical error"

assert none? compile-text {
	Red/System []
	foo: func [return: [integer!]][return]
} 'user "RETURN was accepted without an argument"
assert frontend/last-error/message = "return is missing an argument"
	"missing RETURN argument did not report the canonical error"

return-mismatch-ir: compile-text {
	Red/System []
	foo: func [return: [integer!]][return true]
} 'user
assert binary? return-mismatch-ir [
	"frontend rejected backend-owned RETURN compatibility: " mold frontend/last-error
]
assert (ops-of return-mismatch-ir layout-of return-mismatch-ir) = [1 11]
	"RETURN mismatch did not remain one literal and one sink"

call-mismatch-ir: compile-text {
	Red/System []
	take: func [value [integer!]][]
	run: func [][take true]
} 'user
assert binary? call-mismatch-ir [
	"frontend rejected backend-owned CALL compatibility: " mold frontend/last-error
]
assert none? find (ops-of call-mismatch-ir layout-of call-mismatch-ir) 8
	"CALL mismatch introduced a frontend CAST"

assert none? compile-text {
	Red/System []
	receive: func [values [int-ptr!]][]
	receive [1]
} 'user "a direct call accepted a literal array"
assert frontend/last-error/message =
	"literal arrays cannot be passed as argument"
	"direct literal array did not report the canonical error"

assert none? compile-text {
	Red/System []
	typed-value!: alias struct! [
		type [integer!]
		_align0 [integer!]
		value [int-ptr!]
		_padding [integer!]
		_align1 [integer!]
	]
	receive: func [[typed] count [integer!] list [typed-value!]][]
	receive [[1]]
} 'user "a typed call accepted a nested literal array"
assert frontend/last-error/message =
	"literal arrays cannot be passed as argument"
	["typed literal array did not report the canonical error: "
		mold frontend/last-error]

typed-array-ir: compile-text {
	Red/System []
	typed-value!: alias struct! [
		type [integer!]
		_align0 [integer!]
		value [int-ptr!]
		_padding [integer!]
		_align1 [integer!]
	]
	a: [1]
	b: [:a]
	receive: func [[typed] count [integer!] list [typed-value!]][]
	main: func [][
		receive b
		receive [a]
	]
} 'user
assert binary? typed-array-ir [
	"typed array pointer arguments failed: " mold frontend/last-error
]

assert none? compile-text {
	Red/System []
	d!: alias struct! [i [integer!]]
	d: declare d!
	d: as d! as pointer! d
} 'user "AS accepted POINTER! without a pointee type block"
assert frontend/last-error/message =
	"invalid target type casting: [pointer! d]"
	"invalid compound cast target did not report the canonical error"

print "PASS: typed postfix Red/System frontend"
