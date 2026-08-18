Red/System [
	Title: "RSIR case/switch linked executable fixture"
]

#import [
	"msvcrt.dll" cdecl [
		quit: "exit" [status [integer!]]
	]
]

choose: func [
	value [integer!]
	return: [integer!]
][
	switch value [
		1 [11]
		3 [
			case [
				value = 2 [22]
				true [73]
			]
		]
		default [99]
	]
]

choose-pointer: func [
	value [integer!]
	address [int-ptr!]
	return: [int-ptr!]
][
	case [
		value = 0 [null]
		value = 1 [either true [address][null]]
		true [address]
	]
]

main: func [
	return: [integer!]
	/local value [integer!] pointer [int-ptr!]
][
	value: 73
	pointer: choose-pointer 0 :value
	if pointer <> null [return 1]
	pointer: choose-pointer 1 :value
	if any [pointer = null pointer/value <> 73][return 2]
	pointer: choose-pointer 2 :value
	if any [pointer = null pointer/value <> 73][return 3]
	choose 3
]

quit main
