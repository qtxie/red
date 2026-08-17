Red/System [
	Title: "RSIR PUSH/POP linked executable fixture"
]

#import [
	"msvcrt.dll" cdecl [
		process-exit: "exit" [status [integer!]]
	]
]

roundtrip: func [return: [integer!] /local value [integer!]][
	push 42
	value: pop
	value
]

lifo: func [return: [integer!] /local a [integer!] b [integer!]][
	push 10
	push 20
	b: pop
	a: pop
	(a * 1000) + b
]

expressions: func [return: [integer!] /local n hi lo [integer!]][
	n: 7
	push n * 2
	push n + 1
	lo: pop
	hi: pop
	(hi * 100) + lo
]

variable: func [return: [integer!] /local value [integer!]][
	value: 123
	push value
	pop
]

inside-expression: func [return: [integer!]][
	push 100
	pop + 5
]

float-bits: func [return: [integer!] /local value [float32!]][
	value: as float32! 1.0
	push value
	pop
]

stack-top?: func [return: [logic!] /local value [pointer! [integer!]]][
	value: system/stack/top
	value <> null
]

global-a: 0
global-b: 0
push 10
push 20
global-b: pop
global-a: pop

main: func [return: [integer!]][
	either all [
		roundtrip = 42
		lifo = 10020
		expressions = 1408
		variable = 123
		inside-expression = 105
		float-bits = 3F800000h
		stack-top?
		global-a = 10
		global-b = 20
	][73][1]
]

process-exit main
