Red [
	Title: "Typed postfix hybrid codegen routine smoke tests"
]

#include %../../../compiler/int-to-bin.red
#include %../../../compiler/rsir-frontend.red
#include %../../../compiler/codegen-bridge.red

fail: func [message [string! block!]][
	print ["FAIL:" either block? message [rejoin message][message]]
	quit/return 1
]

check: func [condition [logic! none!] message [string! block!]][
	unless condition [fail message]
]

word-at: func [data [binary!] offset [integer!] /local high][
	high: to integer! pick data (offset + 4)
	(to integer! pick data (offset + 1))
		+ ((to integer! pick data (offset + 2)) * 256)
		+ ((to integer! pick data (offset + 3)) * 65536)
		+ (high * 16777216)
]

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
	status: codegen-module ir artifact 0
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
	function-at: 44
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
check (word-at literal/2 60) = 48 "literal used an unexpected frame shape"

generate "direct call" {
	Red/System []
	id: func [value [integer!] return: [integer!]][value]
	main: func [return: [integer!]][id id 7]
} 'user

generate "left-to-right integer expression" {
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

generate "fifth stack argument" {
	Red/System []
	fifth: func [
		a [integer!] b [integer!] c [integer!] d [integer!] e [integer!]
		return: [integer!]
	][e]
	main: func [return: [integer!]][fifth 1 2 3 4 9]
} 'user

local: generate "inferred local" {
	Red/System []
	fn: func [return: [integer!] /local value][value: 7 value]
} 'user
check (word-at local/2 60) = 64 "local storage was mixed with the value stack"

generate "explicit local assignment result" {
	Red/System []
	fn: func [return: [integer!] /local value [integer!]][value: 7]
} 'user

generate "local shadows global" {
	Red/System []
	value: 1
	fn: func [return: [integer!] /local value][value: 11 value]
} 'user

generate "global load" {
	Red/System [] answer: 42 fn: func [return: [integer!]][answer]
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
status: codegen-module literal/1 small 0
check status = 4 "bridge did not report output exhaustion"

bad: copy literal/1
change/part at bad 17 int-to-bin/to-bin32 100 4
artifact: make binary! 4096
status: codegen-module bad artifact 0
check status = 2 "bridge did not reject an invalid function count"

print "PASS: typed postfix hybrid codegen routine"
