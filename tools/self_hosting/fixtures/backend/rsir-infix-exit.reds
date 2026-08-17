Red/System [
	Title: "RSIR infix function linked executable fixture"
]

#import [
	"msvcrt.dll" cdecl [
		process-exit: "exit" [status [integer!]]
		compare-infix: "strcmp" [
			[infix]
			left [c-string!]
			right [c-string!]
			return: [integer!]
		]
	]
]

add-infix: func [
	"Add two integers"
	[infix]
	a [integer!]
	b [integer!]
	return: [integer!]
][
	a + b
]

double: func [
	value [integer!]
	return: [integer!]
][
	value * 2
]

seen: 0

accept-infix: func [
	[infix]
	label [c-string!]
	ok [logic!]
][
	if all [label <> null ok][seen: 1]
]

main: func [return: [integer!] /local score [integer!]][
	score: 0
	score: score + (2 add-infix 3)
	score: score + (2 add-infix 3 + 4)
	score: score + (2 add-infix (3 + 4))
	score: score + add-infix 2 3
	score: score + (2 add-infix double 3)
	score: score + (2 add-infix 3 add-infix 4)
	"infix" accept-infix (score = 45)
	either all [
		score = 45
		seen = 1
		("same" compare-infix "same") = 0
	][73][score]
]

process-exit main
