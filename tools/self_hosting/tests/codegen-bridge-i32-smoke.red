Red [
	Title: "Typed postfix hybrid codegen routine smoke tests"
]

#include %../../../compiler/int-to-bin.red
#include %../../../compiler/ieee-754.red
#include %../../../compiler/unicode.red
#include %../../../compiler/codegen-bridge.red
#include %../../../compiler/rsir-frontend.red

red-compiler-process-get: func [spec code [block!]][false]
red-compiler-process-in: func [path word code [block!]][false]
red-compiler-process-typecheck: func [spec [word! block!]][none]
red-compiler-expand-call: func [body [block!] global? [logic!]][copy []]

fail: func [message [string! block!]][
	print ["FAIL:" either block? message [rejoin message][message]]
	quit/return 1
]

check: func [condition [logic! none!] message [string! block!]][
	unless condition [fail message]
]

codegen-header-size: 52

word-at: func [data [binary!] offset [integer!] /local high][
	high: to integer! pick data (offset + 4)
	(to integer! pick data (offset + 1))
		+ ((to integer! pick data (offset + 2)) * 256)
		+ ((to integer! pick data (offset + 3)) * 65536)
		+ (high * 16777216)
]

instruction-output: make binary! 1
while [1 = emit-rsir-instruction instruction-output 1 2 3 4][]
instruction-tail: length? instruction-output
compiler-rsir-frontend/emit instruction-output 5 6 7 8
check all [
	(length? instruction-output) = (instruction-tail + 16)
	(word-at instruction-output instruction-tail) = 5
	(word-at instruction-output (instruction-tail + 4)) = 6
	(word-at instruction-output (instruction-tail + 8)) = 7
	(word-at instruction-output (instruction-tail + 12)) = 8
]["native instruction writer did not grow and append atomically"]

generate: func [
	name source [string!]
	kind [word!]
	/local ir artifact status count id function-at frame
][
	ir: compiler-rsir-frontend/compile load source kind
	unless binary? ir [
		fail [name " frontend: " mold compiler-rsir-frontend/last-error]
	]
	artifact: make binary! 65536
	status: codegen-module ir artifact 1 0
	check status = 0 [name " codegen status=" status]
	check all [
		(length? artifact) = word-at artifact 0
		(word-at artifact 4) = word-at ir 0
		(word-at artifact 8) = word-at ir 4
		(word-at artifact 12) = word-at ir 16
		(word-at artifact 28) > 0
		(word-at artifact 32) > 0
		(word-at artifact 36) >= 16
	][name " image header is inconsistent"]
	count: word-at artifact 12
	function-at: codegen-header-size
	id: 0
	while [id < count][
		frame: word-at artifact (function-at + (id * 36) + 16)
		check all [frame >= 32 (frame // 16) = 0][
			name " has an invalid function frame"
		]
		id: id + 1
	]
	reduce [ir artifact]
]

void: generate "void" {Red/System [] fn: func [][]} 'user
literal: generate "literal" {
	Red/System [] fn: func [return: [integer!]][7]
} 'user
check (word-at literal/2 (codegen-header-size + 16)) = 48
	"literal used an unexpected frame shape"

direct-call: generate "direct call" {
	Red/System []
	id: func [value [integer!] return: [integer!]][value]
	main: func [return: [integer!]][id id 7]
} 'user

left-expression: generate "left-to-right integer expression" {
	Red/System []
	fn: func [return: [integer!]][1 + 2 * 3]
} 'user

generate "parenthesized integer expression" {
	Red/System []
	fn: func [return: [integer!]][1 + (2 * 3)]
} 'user

generate "integer operation families" {
	Red/System []
	math: func [a [integer!] b [integer!] return: [integer!]][
		(((a + b - 3) * 5) / 2) % 7
	]
	bits: func [a [integer!] return: [integer!]][
		not (((a << 2) >> 1) >>> 1 or 8 xor 3 and 15)
	]
	mod: func [a [integer!] return: [integer!]][a // -4]
	equal?: func [a [integer!] return: [logic!]][a >= 3]
} 'user

generate "logic operation families" {
	Red/System []
	fn: func [a [logic!] b [logic!] return: [logic!]][not (a and b xor false)]
} 'user

generate "structured conditionals and early return" {
	Red/System []
	choose: func [value [integer!] return: [integer!]][
		if value > 0 [return 7]
		9
	]
	main: func [flag [logic!] return: [integer!] /local value][
		value: either flag [choose 1][choose 0]
		value
	]
} 'user

generate "typed CASE selection" {
	Red/System []
	choose: func [value [integer!] return: [integer!]][
		case [
			value = 1 [11]
			value = 2 [22]
			true [33]
		]
	]
} 'user

generate "typed SWITCH dispatch" {
	Red/System []
	choose: func [value [integer!] return: [integer!]][
		switch value [1 2 [11] 3 [22] default [33]]
	]
	choose-byte: func [value [byte!] return: [byte!]][
		switch value [#"A" [#"B"] #"C" [#"D"] default [#"E"]]
	]
	choose-wide: func [return: [integer!]][
		switch #u64h-0000000100000000 [
			#u64h-0000000100000000 [7]
			default [9]
		]
	]
} 'user

generate "void exit and statement arm reconciliation" {
	Red/System []
	stop: func [flag [logic!] /local value][
		value: 1
		if flag [exit]
		either flag [value][false]
		value: 2
	]
} 'user

generate "short-circuit condition lists" {
	Red/System []
	main: func [a [logic!] b [logic!] return: [logic!] /local value][
		value: any [a b]
		all [value not b]
	]
} 'user

generate "structured integer loops" {
	Red/System []
	main: func [return: [integer!] /local i value][
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

generate "fixed-width integer expression" {
	Red/System []
	fn: func [return: [int64!]][(as int64! 1) + 2]
} 'user

generate "byte expression" {
	Red/System []
	fn: func [return: [byte!]][#"A" + #"^(01)"]
} 'user

generate "scaled pointer expression" {
	Red/System []
	fn: func [
		value [pointer! [integer!]]
		return: [pointer! [integer!]]
	][value + 2]
} 'user

generate "address and one-based pointer indexes" {
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

generate "aggregate member address" {
	Red/System []
	pair!: alias struct! [left [integer!] right [byte!]]
	fn: func [pair [pair!] return: [int-ptr!]][:pair/right]
} 'user

generate "fifth stack argument" {
	Red/System []
	fifth: func [
		a [integer!] b [integer!] c [integer!] d [integer!] e [integer!]
		return: [integer!]
	][e]
	main: func [return: [integer!]][fifth 1 2 3 4 9]
} 'user

generate "Win64 aggregate value ABI" {
	Red/System []
	tiny!: alias struct! [item [byte!]]
	pair!: alias struct! [left [integer!] right [integer!]]
	triple!: alias struct! [one [byte!] two [byte!] three [byte!]]
	medium!: alias struct! [one [integer!] two [integer!] three [integer!]]
	large!: alias struct! [
		one [int64!] two [int64!] three [int64!] four [int64!] five [int64!]
	]
	direct: func [value [pair! value] return: [pair! value]][value]
	hidden: func [value [medium! value] return: [medium! value]][value]
	boundary: func [
		a [integer!] b [integer!] c [integer!] d [integer!]
		value [large! value] tail [integer!]
		return: [large! value]
	][value]
	make: func [base [integer!] return: [triple! value]
		/local value [triple! value]
	][
		value/one: as byte! base
		value
	]
	combine: func [
		left [triple! value] right [triple! value]
		return: [integer!]
	][(as integer! left/one) + (as integer! right/one)]
	main: func [value [pair!] return: [integer!]][
		direct value
		combine make 1 make 2
	]
} 'user

local: generate "inferred local" {
	Red/System []
	fn: func [return: [integer!] /local value][value: 7 value]
} 'user
check (word-at local/2 (codegen-header-size + 16)) = 64
	"local storage was mixed with the value stack"

argument: generate "scalar argument home" {
	Red/System []
	fn: func [value [integer!] return: [integer!]][value]
} 'user

register-loop: generate "register-resident integer loop" {
	Red/System []
	hot-loop: func [
		iterations [integer!]
		return: [integer!]
		/local i sum
	][
		i: 0
		sum: 0
		while [i < iterations][
			sum: sum + (i and 1023)
			i: i + 1
		]
		sum
	]
} 'user

escaped-scalar: generate "escaped scalar parameter" {
	Red/System []
	fn: func [value [integer!] return: [int-ptr!]][:value]
} 'user

escaped-local-access: generate "direct access to an escaped local" {
	Red/System []
	fn: func [return: [integer!] /local value [integer!] p [int-ptr!]][
		value: 7
		p: :value
		value: value + 14
		p/1 + value
	]
} 'user

pointer-index: generate "dynamic and static pointer indexes" {
	Red/System []
	fn: func [
		p [int-ptr!]
		index [integer!]
		return: [integer!]
	][
		p/index: 7
		p/2
	]
} 'user

member-load: generate "direct aggregate member load" {
	Red/System []
	pair!: alias struct! [left [integer!] right [integer!]]
	fn: func [pair [pair!] return: [integer!]][pair/right]
} 'user

pointer-loop: generate "register-resident pointer loop" {
	Red/System []
	wide-cell!: alias struct! [
		a [integer!]
		b [integer!]
		c [integer!]
		d [integer!]
	]

	hot-loop: func [
		base [wide-cell!]
		iterations [integer!]
		return: [wide-cell!]
		/local index [integer!] cursor [wide-cell!]
	][
		index: 0
		cursor: base
		while [index < iterations][
			cursor: cursor + 1
			index: index + 1
		]
		cursor
	]
} 'user

generate "explicit local assignment result" {
	Red/System []
	fn: func [return: [integer!] /local value [integer!]][value: 7]
} 'user

declared-local: generate "owned local aggregate" {
	Red/System []
	wide!: alias struct! [a [int64!] b [int64!] c [int64!]]
	fn: func [return: [integer!] /local value [wide!]][
		value: declare wide!
		value/a: as int64! 73
		as integer! value/a
	]
} 'user
check (word-at declared-local/2 (codegen-header-size + 16)) = 80
	"inline aggregate storage did not contribute its exact size to the frame"

generate "local shadows global" {
	Red/System []
	value: 1
	fn: func [return: [integer!] /local value][value: 11 value]
} 'user

global-scalar: generate "scalar global update" {
	Red/System []
	answer: 1
	fn: func [return: [integer!]][
		answer: answer + 41
		answer
	]
} 'user

global-single: generate "single scalar global load" {
	Red/System []
	answer: 42
	fn: func [return: [integer!]][answer]
} 'user

global-aggregate: generate "owned global aggregate" {
	Red/System []
	pair: declare struct! [left [integer!] right [integer!]]
	fn: func [return: [integer!]][pair/left]
} 'user

global-bytes: generate "global byte payload" {
	Red/System []
	text: "Red"
	fn: func [return: [byte!]][text/2]
} 'user

protected-global-bytes: generate "protected global byte payload" {
	Red/System []
	text: protect "Red"
	fn: func [return: [byte!]][text/2]
} 'user

generate "dynamic global store" {
	Red/System [] answer: 1 answer: 42
} 'glue

generate "import load" {
	Red/System []
	#import ["fixture.dll" stdcall [value: "value" [integer!]]]
	fn: func [return: [integer!]][value]
} 'user

generate "import store" {
	Red/System []
	red: context [
		#import ["fixture.dll" stdcall [boot?: "boot?" [logic!]]]
	]
	red/boot?: yes
} 'glue

import-call: generate "imported scalar call" {
	Red/System []
	#import ["fixture.dll" cdecl [
		negate: "negate" [value [integer!] return: [integer!]]
	]]
	fn: func [return: [integer!]][negate 42]
} 'user

generate "equivalent aggregate aliases" {
	Red/System []
	left!: alias struct! [value [integer!]]
	right!: alias struct! [value [integer!]]
	take-right: func [item [right!] return: [integer!]][item/value]
	forward: func [item [left!] return: [integer!]][take-right item]
} 'user

generate "Red-internal packed variadic import" {
	Red/System []
	#import [
		"fixture.dll" stdcall [
			sink: "sink" [
				[variadic red-internal]
				count [integer!]
				list [pointer! [uint64!]]
			]
		]
	]
	sink [11 22]
} 'glue

generate "c-string call" {
	Red/System []
	red: context [
		#import ["fixture.dll" stdcall [
			make: "make" [text [c-string!] return: [integer!]]
		]]
	]
	symbol: red/make "type"
} 'glue

generate "native layout" {
	Red/System []
	cell!: alias struct! [mark [byte!] value [integer!]]
	fn: func [return: [integer!]][size? cell!]
} 'user

global-address-array: generate "heterogeneous literal address array" {
	Red/System []
	values: ["one" 1 "two"]
	fn: func [][]
} 'user

global-function-array: generate "literal function address array" {
	Red/System []
	int-fn!: alias function! [value [integer!] return: [integer!]]
	double: func [value [integer!] return: [integer!]][value * 2]
	functions: [:double]
	fn: func [][]
} 'user

generate "function address integer casts" {
	Red/System []
	callback!: alias function! [[custom] return: [integer!]]
	address: func [return: [uint64!]][as uint64! :address]
	from-table: func [
		table [pointer! [uint64!]]
		/local callback [callback!]
	][callback: as callback! table/1]
} 'user

c-string: generate "c-string type" {
	Red/System []
	fn: func [text [c-string!] return: [c-string!]][text]
} 'user
check (word-at c-string/1 8) = 0 "c-string unexpectedly created a pointer node"

pointer: generate "parameterized pointer type" {
	Red/System []
	int-ref!: alias pointer! [integer!]
	fn: func [return: [integer!]][7]
} 'user
check all [
	(word-at pointer/1 8) = 2
	pointer/2 = literal/2
]["unused logical pointer types changed native code"]

small: make binary! 64
status: codegen-module literal/1 small 1 0
check status = 4 "bridge did not report output exhaustion"

bad: copy literal/1
change/part at bad 17 int-to-bin/to-bin32 100 4
artifact: make binary! 4096
status: codegen-module bad artifact 1 0
check status = 2 "bridge did not reject an invalid function count"

artifact: make binary! 4096
status: codegen-module literal/1 artifact 2 0
check status = 0 "ARM64 bridge did not generate a literal function"
check all [
	(word-at artifact 0) = length? artifact
	(word-at artifact 12) = 1
	(word-at artifact 16) = 0
	(word-at artifact 20) = 0
	(word-at artifact 32) = 8
	(word-at artifact 36) = 16
	(word-at artifact (codegen-header-size + 16)) = 0
]["ARM64 literal image metadata is inconsistent"]
arm-code-offset: word-at artifact 28
check (copy/part at artifact (arm-code-offset + 1) 8) = #{E0008052C0035FD6}
	"ARM64 literal return used unexpected machine code"

artifact: make binary! 4096
status: codegen-module local/1 artifact 2 0
check status = 0 "ARM64 bridge did not generate an inferred local"
check all [
	(word-at artifact 32) = 40
	(word-at artifact (codegen-header-size + 12)) = 40
	(word-at artifact (codegen-header-size + 16)) = 32
]["ARM64 local did not use one register home"]
arm-code-offset: word-at artifact 28
check (copy/part at artifact (arm-code-offset + 17) 8) = #{F3008052E003132A}
	"ARM64 local value did not remain in x19"

artifact: make binary! 4096
status: codegen-module argument/1 artifact 2 0
check status = 0 "ARM64 bridge did not generate a scalar argument"
check all [
	(word-at artifact 32) = 40
	(word-at artifact (codegen-header-size + 12)) = 40
	(word-at artifact (codegen-header-size + 16)) = 32
]["ARM64 argument did not use one register home"]
arm-code-offset: word-at artifact 28
check (copy/part at artifact (arm-code-offset + 17) 8) = #{F303002AE003132A}
	"ARM64 argument did not move directly through x19"

artifact: make binary! 4096
status: codegen-module direct-call/1 artifact 2 0
check status = 0 "ARM64 bridge did not generate nested direct calls"
check all [
	(word-at artifact 12) = 2
	(word-at artifact 16) = 0
	(word-at artifact 20) = 0
	(word-at artifact (codegen-header-size + 16)) = 32
	(word-at artifact (codegen-header-size + 36 + 16)) = 16
]["ARM64 direct calls have inconsistent metadata or frames"]

artifact: make binary! 4096
status: codegen-module left-expression/1 artifact 2 0
check status = 0 "ARM64 bridge did not generate integer arithmetic"
check (word-at artifact 32) = 8
	"ARM64 literal arithmetic was not folded into registers and immediates"

artifact: make binary! 4096
status: codegen-module register-loop/1 artifact 2 0
check status = 0 "ARM64 bridge did not generate a register-resident loop"
check all [
	(word-at artifact 20) = 0
	(word-at artifact 36) = 16
	(word-at artifact (codegen-header-size + 16)) = 48
	(word-at artifact 32) = 80
]["ARM64 loop image lost its register-only frame shape"]
arm-code-offset: word-at artifact 28
check (copy/part at artifact (arm-code-offset + 41) 12)
	= #{8A260012B5020A0B94060011}
	"ARM64 loop did not use direct logical/add destinations"

artifact: make binary! 4096
status: codegen-module escaped-scalar/1 artifact 2 0
check status = 0 "ARM64 bridge did not generate an escaped scalar parameter"
check (word-at artifact (codegen-header-size + 16)) = 32
	"ARM64 escaped scalar did not use one frame home"
arm-code-offset: word-at artifact 28
check (copy/part at artifact (arm-code-offset + 17) 4) = #{A92300D1}
	"ARM64 escaped scalar did not form its frame address directly"

artifact: make binary! 4096
status: codegen-module escaped-local-access/1 artifact 2 0
check status = 0 "ARM64 bridge did not generate direct escaped-local accesses"
check (word-at artifact (codegen-header-size + 16)) = 32
	"ARM64 escaped local used an inconsistent frame"
check all [
	not none? find artifact #{A9035FB8}
	not none? find artifact #{A9031FB8}
]["ARM64 escaped local did not emit frame loads and stores"]

artifact: make binary! 4096
status: codegen-module pointer-index/1 artifact 2 0
check status = 0 "ARM64 bridge did not generate pointer indexing"
arm-code-offset: word-at artifact 28
check not none? find artifact #{310600514AC9318B}
	"ARM64 dynamic pointer index did not use one extended-register add"
check not none? find artifact #{690640B9}
	"ARM64 static pointer index did not fold into the load displacement"

artifact: make binary! 4096
status: codegen-module member-load/1 artifact 2 0
check status = 0 "ARM64 bridge did not generate an aggregate member load"
arm-code-offset: word-at artifact 28
check (copy/part at artifact (arm-code-offset + 21) 4) = #{690640B9}
	"ARM64 aggregate member did not fold into the load displacement"

artifact: make binary! 4096
status: codegen-module pointer-loop/1 artifact 2 0
check status = 0 "ARM64 bridge did not generate a register-resident pointer loop"
check all [
	(word-at artifact (codegen-header-size + 16)) = 48
	(word-at artifact 36) = 16
]["ARM64 pointer loop lost its register-only frame shape"]
check not none? find artifact #{D6420091B5060011}
	"ARM64 pointer loop did not reduce to direct pointer and index increments"

artifact: make binary! 4096
status: codegen-module global-scalar/1 artifact 2 0
check status = 0 "ARM64 bridge did not generate a scalar global update"
check all [
	(word-at artifact 20) = 1
	(word-at artifact 36) = 20
	(word-at artifact 40) = 1
	(word-at artifact 44) = 0
	(word-at artifact (codegen-header-size + 16)) = 32
	(word-at artifact 96) = 16
	(word-at artifact 100) = 4
	(word-at artifact 104) = 1
	(word-at artifact 108) = 1
	(word-at artifact 112) = 0
	(word-at artifact 116) = 16
]["ARM64 scalar global metadata is inconsistent"]
arm-code-offset: word-at artifact 28
check (copy/part at artifact (arm-code-offset + 17) 8)
	= #{1300009073020091}
	"ARM64 repeated global address was not hoisted into x19"

artifact: make binary! 4096
status: codegen-module import-call/1 artifact 2 0
check status = 0 "ARM64 bridge did not generate imported calls"
arm-import-at: codegen-header-size
	+ ((word-at artifact 12) * 36)
	+ ((word-at artifact 40) * 28)
check all [
	(word-at artifact 16) = 1
	(word-at artifact 20) = 1
	(word-at artifact (arm-import-at + 20)) = 1
]["ARM64 imported call metadata is inconsistent"]

artifact: make binary! 4096
status: codegen-module global-aggregate/1 artifact 2 0
check status = 0 "ARM64 bridge did not generate owned aggregate globals"
check all [
	(word-at artifact 20) >= 2
	(word-at artifact 40) = 2
	(word-at artifact 36) >= 32
]["ARM64 owned aggregate metadata is inconsistent"]

artifact: make binary! 4096
status: codegen-module global-bytes/1 artifact 2 0
check status = 0 "ARM64 bridge did not generate static byte payloads"
check all [
	(word-at artifact 20) = 2
	(word-at artifact 40) = 2
	(word-at artifact 36) = 28
	(word-at artifact 44) = 0
]["ARM64 static byte metadata is inconsistent"]

artifact: make binary! 4096
status: codegen-module protected-global-bytes/1 artifact 2 0
check status = 0 "ARM64 bridge did not generate protected byte payloads"
check all [
	(word-at artifact 20) = 2
	(word-at artifact 36) = 16
	(word-at artifact 40) = 2
	(word-at artifact 44) = 12
]["ARM64 protected byte metadata is inconsistent"]

artifact: make binary! 8192
status: codegen-module global-address-array/1 artifact 2 0
check status = 0 "ARM64 bridge did not generate literal address arrays"
check (word-at artifact 20) = 2
	"ARM64 literal address array lost its static relocations"

artifact: make binary! 4096
status: codegen-module global-function-array/1 artifact 2 0
check status = 0 "ARM64 bridge did not generate function address arrays"
check (word-at artifact 20) >= 1
	"ARM64 function address array lost its static relocation"

artifact: make binary! 4096
status: codegen-module global-single/1 artifact 2 0
check status = 0 "ARM64 bridge did not generate a single scalar global load"
check all [
	(word-at artifact 20) = 1
	(word-at artifact 36) = 20
	(word-at artifact 40) = 1
	(word-at artifact (codegen-header-size + 16)) = 0
	(word-at artifact 116) = 0
]["ARM64 single global load gained unnecessary frame state"]
arm-code-offset: word-at artifact 28
check (copy/part at artifact (arm-code-offset + 1) 8)
	= #{0900009029010091}
	"ARM64 single global load did not use the temporary register directly"

artifact: make binary! 4096
status: codegen-module bad artifact 2 0
check status = 2 "ARM64 bridge did not reject invalid RSIR"
check empty? artifact "invalid ARM64 RSIR changed the output"

artifact: make binary! 4096
status: codegen-module literal/1 artifact 99 0
check status = 1 "bridge accepted an unknown architecture"
check empty? artifact "invalid architecture changed the output"

print "PASS: typed postfix hybrid codegen routine"
