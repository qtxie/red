Red/System [
	Title: "Machine-IR x64 custom call fixture"
]

custom-target: func [
	[custom]
	return: [integer!]
][
	41
]

custom-four!: alias function! [
	[stdcall custom]
	return: [integer!]
]

custom-eight!: alias function! [
	[stdcall custom]
	return: [integer!]
]

#either OS = 'Windows [
	#import [
		"msvcrt.dll" cdecl [
			custom-abs: "abs" [[custom] return: [integer!]]
		]
	]
][
	#import [
		"libc.so.6" cdecl [
			custom-abs: "abs" [[custom] return: [integer!]]
		]
	]
]

seen-a: 0
seen-b: 0
seen-c: 0
seen-d: 0

sum-four: func [
	a [integer!]
	b [integer!]
	c [integer!]
	d [integer!]
	return: [integer!]
][
	seen-a: a
	seen-b: b
	seen-c: c
	seen-d: d
	((a + b) + c) + d
]

sum-eight: func [
	a [integer!]
	b [integer!]
	c [integer!]
	d [integer!]
	e [integer!]
	f [integer!]
	g [integer!]
	h [integer!]
	return: [integer!]
][
	((((((a + b) + c) + d) + e) + f) + g) + h
]

dynamic-count: func [return: [integer!]][8]

dynamic-count-four: func [return: [integer!]][4]

stack-roundtrip: func [
	value [integer!]
	return: [integer!]
][
	push value
	pop
]

float32-stack-bits: func [
	return: [integer!]
	/local value [float32!]
][
	value: as float32! 1.0
	push value
	pop
]

call-custom-direct: func [
	return: [integer!]
][
	custom-target 0
]

call-custom-import: func [
	return: [integer!]
][
	push -17
	custom-abs 1
]

call-custom-pushed: func [
	return: [integer!]
	/local target [custom-four!]
][
	target: as custom-four! :sum-four
	push 4
	push 3
	push 2
	push 1
	target 4
]

call-custom-overflow-literal: func [
	return: [integer!]
	/local target [custom-eight!]
][
	target: as custom-eight! :sum-eight
	push 8
	push 7
	push 6
	push 5
	push 4
	push 3
	push 2
	push 1
	target 8
]

call-custom-overflow-variable: func [
	return: [integer!]
	/local target [custom-eight!] count [integer!]
][
	target: as custom-eight! :sum-eight
	count: 8
	push 8
	push 7
	push 6
	push 5
	push 4
	push 3
	push 2
	push 1
	target count
]

call-custom-overflow-expression: func [
	return: [integer!]
	/local target [custom-eight!]
][
	target: as custom-eight! :sum-eight
	push 8
	push 7
	push 6
	push 5
	push 4
	push 3
	push 2
	push 1
	target dynamic-count
]

call-custom-residual-static: func [
	return: [integer!]
	/local target [custom-four!] result [integer!]
][
	target: as custom-four! :sum-four
	push 99
	push 4
	push 3
	push 2
	push 1
	result: target 4
	result + pop
]

call-custom-residual-variable: func [
	return: [integer!]
	/local target [custom-four!] result count [integer!]
][
	target: as custom-four! :sum-four
	count: 4
	push 99
	push 4
	push 3
	push 2
	push 1
	result: target count
	result + pop
]

call-custom-residual-expression: func [
	return: [integer!]
	/local target [custom-four!] result [integer!]
][
	target: as custom-four! :sum-four
	push 99
	push 4
	push 3
	push 2
	push 1
	result: target dynamic-count-four
	result + pop
]

print-line call-custom-direct
print-line call-custom-import
print-line call-custom-pushed
print-line seen-a
print-line seen-b
print-line seen-c
print-line seen-d
print-line call-custom-overflow-literal
print-line call-custom-overflow-variable
print-line call-custom-overflow-expression
print-line stack-roundtrip 123456789
print-line float32-stack-bits
print-line call-custom-residual-static
print-line call-custom-residual-variable
print-line call-custom-residual-expression
