Red/System [
	Title: "Generated-code materialized short-circuit benchmark"
]

is-one?: func [
	value [integer!]
	return: [logic!]
][
	value = 1
]

any-call?: func [
	head [logic!]
	return: [logic!]
][
	any [head is-one? 1]
]

all-call?: func [
	head [logic!]
	return: [logic!]
][
	all [head is-one? 1]
]

hot-short-circuit-call-loop: func [
	iterations [integer!]
	return: [integer!]
	/local index checksum
][
	index: 0
	checksum: 0
	while [index < iterations][
		checksum: checksum + as integer! any-call? false
		checksum: checksum + as integer! any-call? true
		checksum: checksum + as integer! all-call? false
		checksum: checksum + as integer! all-call? true
		index: index + 1
	]
	checksum
]

print-line hot-short-circuit-call-loop 20000000
