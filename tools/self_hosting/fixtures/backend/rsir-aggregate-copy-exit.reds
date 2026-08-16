Red/System [
	Title: "RSIR inline aggregate copy fixture"
]

#import [
	"msvcrt.dll" cdecl [
		process-exit: "exit" [status [integer!]]
	]
]

pair!: alias struct! [
	left  [integer!]
	right [integer!]
]

medium!: alias struct! [
	one   [integer!]
	two   [integer!]
	three [integer!]
]

raw!: alias union! [
	wide [int64!]
	low  [integer!]
]

large!: alias struct! [
	one   [int64!]
	two   [int64!]
	three [int64!]
	four  [int64!]
	five  [int64!]
]

copies!: alias struct! [
	guard-a       [integer!]
	pair-source   [pair! value]
	pair-target   [pair! value]
	medium-source [medium! value]
	medium-target [medium! value]
	raw-source    [raw! value]
	raw-target    [raw! value]
	large-source  [large! value]
	large-target  [large! value]
	guard-b       [integer!]
]

main: func [
	return: [integer!]
	/local score [integer!] copies [copies!]
][
	score: 0
	copies: declare copies!
	copies/guard-a: 1001
	copies/guard-b: 1002

	copies/pair-source/left: 17
	copies/pair-source/right: 18
	copies/pair-target: copies/pair-source
	copies/pair-source/left: 71
	if copies/pair-target/left = 17 [score: score + 1]
	if copies/pair-target/right = 18 [score: score + 1]
	if copies/pair-source/left = 71 [score: score + 1]

	copies/medium-source/one: 21
	copies/medium-source/two: 22
	copies/medium-source/three: 23
	copies/medium-target: copies/medium-source
	copies/medium-source/three: 73
	if copies/medium-target/one = 21 [score: score + 1]
	if copies/medium-target/two = 22 [score: score + 1]
	if copies/medium-target/three = 23 [score: score + 1]
	if copies/medium-source/three = 73 [score: score + 1]

	copies/raw-source/wide: as int64! -1
	copies/raw-target: copies/raw-source
	copies/raw-source/low: 0
	if copies/raw-target/wide = (as int64! -1) [
		score: score + 1
	]
	if copies/raw-source/wide <> (as int64! -1) [
		score: score + 1
	]

	copies/large-source/one: as int64! 31
	copies/large-source/two: as int64! 32
	copies/large-source/three: as int64! 33
	copies/large-source/four: as int64! 34
	copies/large-source/five: as int64! 35
	copies/large-target: copies/large-source
	copies/large-source/one: as int64! 81
	copies/large-source/five: as int64! 85
	if copies/large-target/one = (as int64! 31) [score: score + 1]
	if copies/large-target/three = (as int64! 33) [score: score + 1]
	if copies/large-target/five = (as int64! 35) [score: score + 1]
	if copies/large-source/one = (as int64! 81) [score: score + 1]
	if copies/large-source/five = (as int64! 85) [score: score + 1]

	if copies/guard-a = 1001 [score: score + 1]
	if copies/guard-b = 1002 [score: score + 1]
	if (size? pair!) = 8 [score: score + 1]
	if (size? medium!) = 12 [score: score + 1]
	if (size? raw!) = 8 [score: score + 1]
	if (size? large!) = 40 [score: score + 1]

	either score = 20 [73][score]
]

process-exit main
