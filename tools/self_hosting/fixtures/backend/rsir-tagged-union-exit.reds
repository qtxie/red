Red/System [
	Title: "RSIR tagged union fixture"
]

#import [
	"msvcrt.dll" cdecl [
		process-exit: "exit" [status [integer!]]
	]
]

point!: alias struct! [
	x [integer!]
	y [integer!]
]

value!: alias union! [
	[variant]
	i32   [integer!]
	wide  [int64!]
	point [point! value]
]

event!: alias union! [
	[variant]
	mouse [
		x [integer!]
		y [integer!]
	]
	key [
		code [integer!]
	]
]

box!: alias struct! [
	head  [integer!]
	event [event! value]
	copy  [event! value]
	tail  [integer!]
]

outer!: alias union! [
	[variant]
	wrapped [
		inner [event! value]
		stamp [integer!]
	]
	empty [integer!]
]

main: func [
	return: [integer!]
	/local score before [integer!] value [value!] box [box!] outer [outer!]
][
	score: 0
	value: declare value!
	if not variant? value 'i32 [score: score + 1]
	value/i32: 10
	if variant? value 'i32 [score: score + 1]
	if not variant? value 'wide [score: score + 1]

	value/wide: either variant? value 'i32 [as int64! 20][as int64! 30]
	if variant? value 'wide [score: score + 1]
	if value/wide = (as int64! 20) [score: score + 1]
	if not variant? value 'i32 [score: score + 1]

	box: declare box!
	box/head: 101
	box/tail: 202
	box/event/mouse/x: 11
	box/event/mouse/y: 22
	if variant? box/event 'mouse [score: score + 1]
	if box/event/mouse/x = 11 [score: score + 1]
	if box/event/mouse/y = 22 [score: score + 1]

	box/copy: box/event
	box/event/key/code: 33
	if variant? box/event 'key [score: score + 1]
	if variant? box/copy 'mouse [score: score + 1]
	if box/copy/mouse/x = 11 [score: score + 1]
	if box/copy/mouse/y = 22 [score: score + 1]
	if box/event/key/code = 33 [score: score + 1]
	if box/head = 101 [score: score + 1]
	if box/tail = 202 [score: score + 1]

	switch box/copy [
		mouse [score: score + 1]
		key [score: score + 10]
	]
	before: score
	switch box/event [mouse [score: 0]]
	if score = before [score: score + 1]

	outer: declare outer!
	outer/wrapped/inner/mouse/x: 41
	outer/wrapped/inner/mouse/y: 42
	outer/wrapped/stamp: 43
	if variant? outer 'wrapped [score: score + 1]
	if variant? outer/wrapped/inner 'mouse [score: score + 1]
	if outer/wrapped/inner/mouse/x = 41 [score: score + 1]
	if outer/wrapped/inner/mouse/y = 42 [score: score + 1]
	if outer/wrapped/stamp = 43 [score: score + 1]

	outer/wrapped/inner/key/code: 44
	if variant? outer 'wrapped [score: score + 1]
	if variant? outer/wrapped/inner 'key [score: score + 1]
	if outer/wrapped/inner/key/code = 44 [score: score + 1]

	if (size? value!) = 16 [score: score + 1]
	if (size? event!) = 12 [score: score + 1]
	if (size? outer!) = 20 [score: score + 1]
	if (size? box!) = 32 [score: score + 1]

	either score = 30 [73][score]
]

process-exit main
