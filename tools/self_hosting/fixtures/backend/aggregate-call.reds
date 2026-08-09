Red/System [
	Title: "O2 aggregate call ABI coverage"
]

pair!: alias struct! [
	left  [integer!]
	right [integer!]
]

quad!: alias struct! [
	a [integer!]
	b [integer!]
	c [integer!]
	d [integer!]
]

sept!: alias struct! [
	a [integer!]
	b [integer!]
	c [integer!]
	d [integer!]
	e [integer!]
	f [integer!]
	g [integer!]
]

triple8!: alias struct! [
	one   [byte!]
	two   [byte!]
	three [byte!]
]

sum-pair: func [value [pair! value] return: [integer!]][
	value/left + value/right
]

sum-mixed: func [
	head [integer!]
	value [quad! value]
	tail [integer!]
	return: [integer!]
][
	head + value/a + value/b + value/c + value/d + tail
]

sum-stack: func [
	head [integer!]
	value [sept! value]
	tail [integer!]
	return: [integer!]
][
	head + value/a + value/b + value/c + value/d + value/e + value/f + value/g + tail
]

sum-pair-pointer: func [value [pair!] return: [integer!]][
	value/left + value/right
]

sum-triple8: func [value [triple8! value] return: [integer!]][
	(as integer! value/one) + (as integer! value/two) + (as integer! value/three)
]

call-pair: func [
	left [integer!]
	right [integer!]
	return: [integer!]
	/local value [pair! value]
][
	value/left: left
	value/right: right
	sum-pair value
]

call-mixed: func [
	return: [integer!]
	/local value [quad! value]
][
	value/a: 1
	value/b: 2
	value/c: 4
	value/d: 8
	sum-mixed 16 value 32
]

call-stack: func [
	return: [integer!]
	/local value [sept! value]
][
	value/a: 1
	value/b: 2
	value/c: 3
	value/d: 4
	value/e: 5
	value/f: 6
	value/g: 7
	sum-stack 8 value 16
]

call-pointer: func [
	return: [integer!]
	/local value [pair! value]
][
	value/left: 10
	value/right: 20
	sum-pair-pointer value
]

call-triple8: func [return: [integer!] /local value [triple8! value]][
	value/one: #"A"
	value/two: #"B"
	value/three: #"C"
	sum-triple8 value
]

print-line call-pair 12 30
print-line call-mixed
print-line call-stack
print-line call-pointer
print-line call-triple8
