Red/System [
	Title: "RSIR custom call linked executable fixture"
]

custom-four!: alias function! [
	[stdcall custom]
	return: [integer!]
]

custom-eight!: alias function! [
	[stdcall custom]
	return: [integer!]
]

#import [
	"msvcrt.dll" cdecl [
		process-exit: "exit" [status [integer!]]
		custom-abs: "abs" [[custom] return: [integer!]]
	]
]

custom-target: func [[custom] return: [integer!]][41]

sum-four: func [
	a b c d [integer!]
	return: [integer!]
][
	(((a * 1000) + (b * 100)) + (c * 10)) + d
]

sum-eight: func [
	a b c d e f g h [integer!]
	return: [integer!]
	/local value [integer!]
][
	value: a
	value: (value * 10) + b
	value: (value * 10) + c
	value: (value * 10) + d
	value: (value * 10) + e
	value: (value * 10) + f
	value: (value * 10) + g
	(value * 10) + h
]

dynamic-eight: func [return: [integer!]][8]
dynamic-four: func [return: [integer!]][4]

call-direct: func [return: [integer!]][custom-target 0]

call-import: func [return: [integer!]][
	push -17
	custom-abs 1
]

call-four: func [return: [integer!] /local target [custom-four!]][
	target: as custom-four! :sum-four
	push 4
	push 3
	push 2
	push 1
	target 4
]

call-eight-dynamic: func [return: [integer!] /local target [custom-eight!]][
	target: as custom-eight! :sum-eight
	push 8
	push 7
	push 6
	push 5
	push 4
	push 3
	push 2
	push 1
	target dynamic-eight
]

call-residual: func [
	return: [integer!]
	/local target [custom-four!] result [integer!]
][
	target: as custom-four! :sum-four
	push 99
	push 4
	push 3
	push 2
	push 1
	result: target dynamic-four
	result + pop
]

main: func [return: [integer!]][
	either all [
		call-direct = 41
		call-import = 17
		call-four = 1234
		call-eight-dynamic = 12345678
		call-residual = 1333
	][73][1]
]

process-exit main
