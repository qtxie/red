Red/System [
	Title: "O2 short-circuit fallback coverage"
]

touches: 0

touch-true?: func [
	return: [logic!]
][
	touches: touches + 1
	true
]

any-word-like?: func [
	type [integer!]
	return: [logic!]
][
	any [
		type = 15
		type = 16
		type = 17
		type = 18
		type = 19
		type = 20
	]
]

all-in-range?: func [
	value [integer!]
	return: [logic!]
][
	all [
		value > 0
		value < 10
		value <> 5
	]
]

any-skips-tail?: func [
	return: [logic!]
][
	touches: 0
	all [
		any [true touch-true?]
		touches = 0
	]
]

all-skips-tail?: func [
	return: [logic!]
][
	touches: 0
	any [
		all [false touch-true?]
		touches = 0
	]
]

any-calls-tail?: func [
	head [logic!]
	return: [logic!]
][
	touches: 0
	any [head touch-true?]
]

all-calls-tail?: func [
	head [logic!]
	return: [logic!]
][
	touches: 0
	all [head touch-true?]
]

print-line any-word-like? 15
print-line any-word-like? 20
print-line any-word-like? 14
print-line all-in-range? 4
print-line all-in-range? 5
print-line all-in-range? 10
print-line any-skips-tail?
print-line all-skips-tail?
print-line any-calls-tail? false
print-line touches
print-line any-calls-tail? true
print-line touches
print-line all-calls-tail? false
print-line touches
print-line all-calls-tail? true
print-line touches
