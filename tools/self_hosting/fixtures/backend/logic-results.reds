Red/System [
	Title: "O2 materialized comparison result coverage"
]

less-result?: func [
	left [integer!]
	right [integer!]
	return: [logic!]
][
	left < right
]

equal-result?: func [
	left [integer!]
	right [integer!]
	return: [logic!]
][
	left = right
]

stored-result?: func [
	left [integer!]
	right [integer!]
	return: [logic!]
	/local result [logic!]
][
	result: left >= right
	result
]

logic-identity: func [
	value [logic!]
	return: [logic!]
][
	value
]

called-result?: func [
	left [integer!]
	right [integer!]
	return: [logic!]
][
	logic-identity left <> right
]

print-line less-result? 2 3
print-line less-result? 3 2
print-line equal-result? 4 4
print-line equal-result? 4 5
print-line stored-result? 7 6
print-line stored-result? 6 7
print-line called-result? 8 9
print-line called-result? 9 9
