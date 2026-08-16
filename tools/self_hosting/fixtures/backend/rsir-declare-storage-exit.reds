Red/System [
	Title: "RSIR declare ownership and storage fixture"
]

#import [
	"msvcrt.dll" cdecl [
		process-exit: "exit" [status [integer!]]
	]
]

pair!: alias struct! [
	left  [integer!]
	right [integer!]
	wide  [int64!]
]

holder!: alias struct! [
	pair [pair!]
]

raw!: alias union! [
	wide [int64!]
	low  [integer!]
]

global-pair: declare pair!
global-holder: declare holder!
global-holder/pair: declare pair!

frame-depth: func [
	depth [integer!]
	return: [integer!]
	/local pair [pair!] result [integer!]
][
	pair: declare pair!
	if pair/left <> 0 [return -1]
	if pair/right <> 0 [return -2]
	pair/left: depth
	either depth = 0 [
		1
	][
		result: frame-depth (depth - 1)
		if pair/left <> depth [return -3]
		result + 1
	]
]

main: func [
	return: [integer!]
	/local score [integer!] pair [pair!] holder [holder!] raw [raw!]
][
	score: 0
	if global-pair/left = 0 [score: score + 1]
	if global-pair/right = 0 [score: score + 1]
	global-pair/left: 10
	if global-pair/left = 10 [score: score + 1]
	if global-holder/pair/left = 0 [score: score + 1]
	global-holder/pair/left: 11
	if global-holder/pair/left = 11 [score: score + 1]

	pair: declare pair!
	if pair/left = 0 [score: score + 1]
	if pair/right = 0 [score: score + 1]
	pair/left: 20
	if pair/left = 20 [score: score + 1]

	holder: declare holder!
	holder/pair: declare pair!
	if holder/pair/left = 0 [score: score + 1]
	if holder/pair/right = 0 [score: score + 1]
	holder/pair/right: 30
	if holder/pair/right = 30 [score: score + 1]

	raw: declare raw!
	if (size? raw!) = 8 [score: score + 1]
	if raw/wide = (as int64! 0) [score: score + 1]
	raw/low: 31
	if raw/wide = (as int64! 31) [score: score + 1]

	if (frame-depth 3) = 4 [score: score + 1]
	either score = 15 [73][score]
]

process-exit main
