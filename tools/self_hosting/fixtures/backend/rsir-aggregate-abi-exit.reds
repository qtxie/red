Red/System [
	Title: "RSIR Win64 aggregate value ABI fixture"
]

#import [
	"msvcrt.dll" cdecl [
		process-exit: "exit" [status [integer!]]
	]
]

tiny!: alias struct! [item [byte!]]

pair!: alias struct! [
	left  [integer!]
	right [integer!]
]

triple!: alias struct! [
	one   [byte!]
	two   [byte!]
	three [byte!]
]

medium!: alias struct! [
	one   [integer!]
	two   [integer!]
	three [integer!]
]

paird!: alias struct! [
	one [float!]
	two [float!]
]

large!: alias struct! [
	one   [int64!]
	two   [int64!]
	three [int64!]
	four  [int64!]
	five  [int64!]
]

raw!: alias union! [
	wide [int64!]
	low  [integer!]
]

step-tiny: func [
	value [tiny! value]
	marker [integer!]
	return: [tiny! value]
][
	if marker = 11 [value/item: #"X"]
	value
]

step-pair: func [
	value [pair! value]
	marker [integer!]
	return: [pair! value]
][
	if marker = 12 [
		value/left: 31
		value/right: 32
	]
	value
]

step-triple: func [
	value [triple! value]
	marker [integer!]
	return: [triple! value]
][
	if marker = 13 [
		value/one: #"D"
		value/two: #"E"
		value/three: #"F"
	]
	return value
]

step-medium: func [
	value [medium! value]
	marker [integer!]
	return: [medium! value]
][
	if marker = 14 [
		value/one: 41
		value/two: 42
		value/three: 43
	]
	value
]

step-paird: func [
	value [paird! value]
	marker [integer!]
	return: [paird! value]
][
	if marker = 15 [
		value/one: 15.5
		value/two: 16.5
	]
	value
]

step-raw: func [
	value [raw! value]
	marker [integer!]
	return: [raw! value]
][
	value/low: marker
	value
]

check-pair-stack: func [
	a [integer!] b [integer!] c [integer!] d [integer!]
	value [pair! value]
	tail [integer!]
	return: [integer!]
][
	either all [
		a = 1 b = 2 c = 3 d = 4
		value/left = 3 value/right = 4 tail = 5
	][1][0]
]

check-medium-stack: func [
	a [integer!] b [integer!] c [integer!] d [integer!]
	value [medium! value]
	tail [integer!]
	return: [integer!]
][
	either all [
		a = 1 b = 2 c = 3 d = 4
		value/one = 5 value/two = 6 value/three = 7 tail = 8
	][1][0]
]

large-boundary: func [
	a [integer!] b [integer!] c [integer!] d [integer!]
	value [large! value]
	tail [integer!]
	return: [large! value]
	/local result [large! value]
][
	result/one: as int64! (a + b + c + d)
	result/two: as int64! tail
	result/three: value/three
	result/four: value/four
	result/five: value/five
	value/one: as int64! 99
	result
]

make-pair: func [
	base [integer!]
	return: [pair! value]
	/local result [pair! value]
][
	result/left: base
	result/right: base + 1
	result
]

pair-code: func [
	left [pair! value]
	right [pair! value]
	return: [integer!]
][
	(left/left * 10) + right/left
]

make-medium: func [
	base [integer!]
	return: [medium! value]
	/local result [medium! value]
][
	result/one: base
	result/two: base + 1
	result/three: base + 2
	result
]

medium-code: func [
	left [medium! value]
	right [medium! value]
	return: [integer!]
][
	(left/one * 10) + right/one
]

main: func [
	return: [integer!]
	/local score [integer!]
		tiny-source [tiny! value] tiny-result [tiny! value]
		pair-source [pair! value] pair-result [pair! value]
		triple-source [triple! value] triple-result [triple! value]
		medium-source [medium! value] medium-result [medium! value]
		paird-source [paird! value] paird-result [paird! value]
		large-source [large! value] large-result [large! value]
		raw-source [raw! value] raw-result [raw! value]
][
	score: 0

	tiny-source/item: #"A"
	tiny-result: step-tiny tiny-source 11
	if tiny-result/item = #"X" [score: score + 1]
	if tiny-source/item = #"A" [score: score + 1]

	pair-source/left: 3
	pair-source/right: 4
	pair-result: step-pair pair-source 12
	if pair-result/left = 31 [score: score + 1]
	if pair-result/right = 32 [score: score + 1]
	if pair-source/left = 3 [score: score + 1]
	if pair-source/right = 4 [score: score + 1]

	triple-source/one: #"A"
	triple-source/two: #"B"
	triple-source/three: #"C"
	triple-result: step-triple triple-source 13
	if all [
		triple-result/one = #"D"
		triple-result/two = #"E"
		triple-result/three = #"F"
	][score: score + 1]
	if all [
		triple-source/one = #"A"
		triple-source/two = #"B"
		triple-source/three = #"C"
	][score: score + 1]

	medium-source/one: 5
	medium-source/two: 6
	medium-source/three: 7
	medium-result: step-medium medium-source 14
	if all [
		medium-result/one = 41
		medium-result/two = 42
		medium-result/three = 43
	][score: score + 1]
	if all [
		medium-source/one = 5
		medium-source/two = 6
		medium-source/three = 7
	][score: score + 1]

	paird-source/one: 1.5
	paird-source/two: 2.5
	paird-result: step-paird paird-source 15
	if all [paird-result/one = 15.5 paird-result/two = 16.5][score: score + 1]
	if all [paird-source/one = 1.5 paird-source/two = 2.5][score: score + 1]

	raw-source/low: 7
	raw-result: step-raw raw-source 91
	if raw-result/low = 91 [score: score + 1]
	if raw-source/low = 7 [score: score + 1]

	if (check-pair-stack 1 2 3 4 pair-source 5) = 1 [score: score + 1]
	if (check-medium-stack 1 2 3 4 medium-source 8) = 1 [score: score + 1]

	large-source/one: as int64! 1
	large-source/two: as int64! 2
	large-source/three: as int64! 3
	large-source/four: as int64! 4
	large-source/five: as int64! 5
	large-result: large-boundary 10 20 30 40 large-source 50
	if all [
		large-result/one = (as int64! 100)
		large-result/two = (as int64! 50)
		large-result/three = (as int64! 3)
		large-result/four = (as int64! 4)
		large-result/five = (as int64! 5)
	][score: score + 1]
	if all [
		large-source/one = (as int64! 1)
		large-source/two = (as int64! 2)
		large-source/three = (as int64! 3)
		large-source/four = (as int64! 4)
		large-source/five = (as int64! 5)
	][score: score + 1]

	if (pair-code make-pair 1 make-pair 2) = 12 [score: score + 1]
	if (medium-code make-medium 1 make-medium 2) = 12 [score: score + 1]

	if (size? tiny!) = 1 [score: score + 1]
	if (size? pair!) = 8 [score: score + 1]
	if (size? triple!) = 3 [score: score + 1]
	if (size? medium!) = 12 [score: score + 1]
	if (size? paird!) = 16 [score: score + 1]
	if (size? large!) = 40 [score: score + 1]
	if (size? raw!) = 8 [score: score + 1]

	either score = 27 [73][score]
]

process-exit main
