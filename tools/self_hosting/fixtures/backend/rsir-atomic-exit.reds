Red/System [
	Title: "RSIR system/atomic linked executable fixture"
]

#import [
	"msvcrt.dll" cdecl [
		process-exit: "exit" [status [integer!]]
	]
]

atomic-cell!: alias struct! [
	padding [integer!]
	value [integer!]
]

state: 0
argument-order: 0

atomic-address: func [return: [pointer! [integer!]]][
	argument-order: (argument-order * 10) + 1
	:state
]

atomic-value: func [digit [integer!] return: [integer!]][
	argument-order: (argument-order * 10) + digit
	digit
]

argument-order-test: func [
	return: [logic!]
	/local changed? [logic!]
][
	argument-order: 0
	system/atomic/store :state 2
	changed?: system/atomic/cas atomic-address atomic-value 2 atomic-value 3
	all [changed? argument-order = 123 state = 3]
]

global-operations: func [
	return: [integer!]
	/local previous current [integer!] changed? [logic!]
][
	system/atomic/store :state 1
	current: system/atomic/load :state
	if current <> 1 [return 1]

	previous: system/atomic/add/old :state 2
	if any [previous <> 1 state <> 3][return 2]
	previous: system/atomic/sub/old :state 1
	if any [previous <> 3 state <> 2][return 3]
	previous: system/atomic/or/old :state 4
	if any [previous <> 2 state <> 6][return 4]
	previous: system/atomic/xor/old :state 3
	if any [previous <> 6 state <> 5][return 5]
	previous: system/atomic/and/old :state 6
	if any [previous <> 5 state <> 4][return 6]

	current: system/atomic/add :state 2
	if any [current <> 6 state <> 6][return 7]
	current: system/atomic/sub :state 1
	if any [current <> 5 state <> 5][return 8]
	current: system/atomic/or :state 8
	if any [current <> 13 state <> 13][return 9]
	current: system/atomic/xor :state 1
	if any [current <> 12 state <> 12][return 10]
	current: system/atomic/and :state 10
	if any [current <> 8 state <> 8][return 11]

	changed?: system/atomic/cas :state 8 11
	if any [not changed? state <> 11][return 12]
	changed?: system/atomic/cas :state 8 12
	if any [changed? state <> 11][return 13]

	system/atomic/fence
	current: 1 / 1
	system/atomic/store :state 2147483647
	current: system/atomic/add :state 1
	if any [not system/cpu/overflow? current <> -2147483648][return 14]

	11
]

member-operations: func [
	return: [integer!]
	/local cell [atomic-cell!]
][
	cell: declare atomic-cell!
	system/atomic/store :cell/value 73
	system/atomic/load :cell/value
]

main: func [return: [integer!]][
	either all [
		argument-order-test
		global-operations = 11
		member-operations = 73
	][73][1]
]

process-exit main
