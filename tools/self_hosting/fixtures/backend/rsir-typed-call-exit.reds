Red/System [
	Title: "RSIR typed call executable fixture"
]

#import [
	"msvcrt.dll" cdecl [
		process-exit: "exit" [status [integer!]]
	]
]

typed-value!: alias struct! [
	type     [integer!]
	_align0  [integer!]
	value    [int-ptr!]
	_padding [integer!]
	_align1  [integer!]
]

typed-float32!: alias struct! [
	type     [integer!]
	_align0  [integer!]
	value    [float32!]
	_padding [int64!]
]

typed-float!: alias struct! [
	type     [integer!]
	_align0  [integer!]
	value    [float!]
	_padding [integer!]
]

sample!: alias struct! [value [integer!]]

octet!: alias byte!

typed-sink!: alias function! [
	[typed]
	count [integer!]
	list [typed-value!]
	return: [integer!]
]

global-value: 42
global-float32: as float32! 1.0

identity: func [value [integer!] return: [integer!]][value]

typed-value-as-integer: func [
	item [typed-value!]
	return: [integer!]
][
	as integer! item/value
]

check-values: func [
	[typed]
	count [integer!]
	list [typed-value!]
	return: [integer!]
	/local score [integer!] item [sample!]
][
	score: 0
	if count = 19 [score: score + 1]
	if all [list/type = 3 (typed-value-as-integer list) = 65][score: score + 1]
	list: list + 1
	if all [list/type = 1 (typed-value-as-integer list) = 1][score: score + 1]
	list: list + 1
	if all [list/type = 14 (typed-value-as-integer list) = 250][score: score + 1]
	list: list + 1
	if all [list/type = 13 (typed-value-as-integer list) = -2][score: score + 1]
	list: list + 1
	if all [list/type = 15 (typed-value-as-integer list) = -300][score: score + 1]
	list: list + 1
	if all [list/type = 16 (typed-value-as-integer list) = 60000][score: score + 1]
	list: list + 1
	if all [list/type = 2 (typed-value-as-integer list) = -123456][score: score + 1]
	list: list + 1
	if all [list/type = 17 (typed-value-as-integer list) = -1][score: score + 1]
	list: list + 1
	if all [
		list/type = 11
		(typed-value-as-integer list) = -3
		list/_padding = -1
	][score: score + 1]
	list: list + 1
	if all [
		list/type = 12
		(typed-value-as-integer list) = -1
		list/_padding = 0
	][score: score + 1]
	list: list + 1
	if all [list/type = 6 list/value <> null][score: score + 1]
	list: list + 1
	if all [list/type = 7 list/value <> null][score: score + 1]
	list: list + 1
	if all [list/type = 7 list/value <> null][score: score + 1]
	list: list + 1
	if all [list/type = 8 list/value <> null][score: score + 1]
	list: list + 1
	if all [list/type = 10 list/value <> null][score: score + 1]
	list: list + 1
	if all [list/type = 9 list/value <> null][score: score + 1]
	list: list + 1
	if all [list/type = 3 (typed-value-as-integer list) = 66][score: score + 1]
	list: list + 1
	item: as sample! list/value
	if all [list/type = 1004 item/value = 77][score: score + 1]
	list: list + 1
	if all [list/type = 1001 list/value <> null][score: score + 1]
	score
]

check-float32: func [
	[typed]
	count [integer!]
	list [typed-float32!]
	return: [integer!]
][
	either all [count = 1 list/type = 4 list/value = (as float32! 1.5)][1][0]
]

check-float: func [
	[typed]
	count [integer!]
	list [typed-float!]
	return: [integer!]
][
	either all [count = 1 list/type = 5 list/value = 2.5][1][0]
]

check-one: func [
	[typed]
	count [integer!]
	list [typed-value!]
	return: [integer!]
][
	either all [
		count = 1
		list/type = 2
		(typed-value-as-integer list) = 123
	][1][0]
]

main: func [
	return: [integer!]
	/local score [integer!] item [sample!]
		choice [union! [left [integer!] right [integer!]]] sink [typed-sink!]
][
	item: declare sample!
	item/value: 77
	choice: declare union! [left [integer!] right [integer!]]
	choice/left: 9
	score: check-values [
		#"A"
		true
		as uint8! 250
		as int8! -2
		as int16! -300
		as uint16! 60000
		as int32! -123456
		as uint32! FFFFFFFFh
		as int64! -3
		as uint64! 00000000FFFFFFFFh
		"text"
		as byte-ptr! "bytes"
		:global-float32
		:global-value
		as ptr-ptr! :global-value
		:identity
		as octet! 66
		item
		choice
	]
	score: score + check-float32 [as float32! 1.5]
	score: score + check-float [2.5]
	sink: as typed-sink! :check-one
	score: score + (sink [123])
	either score = 23 [73][score]
]

process-exit main
