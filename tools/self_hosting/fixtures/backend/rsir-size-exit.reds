Red/System [
	Title: "RSIR SIZE? executable fixture"
]

#import [
	"msvcrt.dll" cdecl [
		process-exit: "exit" [status [integer!]]
	]
]

pair!: alias struct! [
	tag   [byte!]
	value [integer!]
	text  [c-string!]
]

global-pair: declare pair!
global-text: "Red"

main: func [
	return: [integer!]
	/local score [integer!] text [c-string!] local [pair!]
][
	score: 0
	if (size? byte!) = 1 [score: score + 1]
	if (size? integer!) = 4 [score: score + 1]
	if (size? pointer!) = 8 [score: score + 1]
	if (size? pair!) = 16 [score: score + 1]
	if (size? global-pair) = 16 [score: score + 1]
	if (size? global-pair/tag) = 1 [score: score + 1]
	if (size? global-text) = 4 [score: score + 1]
	text: "Hybrid"
	if (size? text) = 7 [score: score + 1]
	local: declare pair!
	if (size? local) = 16 [score: score + 1]
	local/text: "RS"
	if (size? local/text) = 3 [score: score + 1]
	if (size? "A") = 2 [score: score + 1]
	if (size? true) = 4 [score: score + 1]
	either score = 12 [73][score]
]

process-exit main
