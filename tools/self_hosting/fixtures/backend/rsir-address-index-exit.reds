Red/System [
	Title: "RSIR address and one-based index executable fixture"
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

holder!: alias struct! [
	slot [int-ptr!]
]

global-cell: 17

address-score: func [
	return: [integer!]
	/local
		score index scalar [integer!]
		wide [int64!]
		real [float!]
		p q copy field [int-ptr!]
		pp [ptr-ptr!]
		bytes [byte-ptr!]
		text [c-string!]
		fp [pointer! [float!]]
		pair [pair!]
		holder [holder!]
][
	score: 0

	scalar: 41
	p: :scalar
	if p/value = 41 [score: score + 1]
	p/1: 42
	if scalar = 42 [score: score + 1]
	index: 1
	p/index: 43
	if scalar = 43 [score: score + 1]

	pp: :p
	if pp/value = (as pointer! p) [score: score + 1]
	copy: as int-ptr! pp/value
	if copy/value = 43 [score: score + 1]

	p: :global-cell
	if p/value = 17 [score: score + 1]
	p/value: 18
	if global-cell = 18 [score: score + 1]

	wide: as int64! 0
	p: as int-ptr! :wide
	p/1: 11
	p/2: 22
	if p/1 = 11 [score: score + 1]
	if p/2 = 22 [score: score + 1]
	index: 2
	if p/index = 22 [score: score + 1]
	q: p + 1
	if q/0 = 11 [score: score + 1]

	bytes: as byte-ptr! :wide
	bytes/1: #"A"
	bytes/2: #"B"
	bytes/8: #"H"
	if bytes/1 = #"A" [score: score + 1]
	if bytes/8 = #"H" [score: score + 1]
	index: 2
	if bytes/index = #"B" [score: score + 1]
	text: as c-string! bytes
	if text/1 = #"A" [score: score + 1]
	if text/index = #"B" [score: score + 1]
	text: "Red"
	if text/2 = #"e" [score: score + 1]

	real: 1.5
	fp: :real
	if fp/value = 1.5 [score: score + 1]
	fp/value: 2.5
	if real = 2.5 [score: score + 1]

	wide: as int64! 0
	pair: as pair! :wide
	pair/left: 71
	if pair/left = 71 [score: score + 1]
	field: :pair/left
	if field/value = 71 [score: score + 1]
	field/value: 72
	if pair/left = 72 [score: score + 1]

	wide: as int64! 0
	scalar: 81
	holder: as holder! :wide
	holder/slot: :scalar
	if holder/slot/value = 81 [score: score + 1]
	holder/slot/value: 82
	if scalar = 82 [score: score + 1]

	either score = 24 [73][score]
]

process-exit address-score
