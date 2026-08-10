Red/System [
	Title: "O2 IF statement result isolation"
]

nested-if-statement: func [
	outer [logic!]
	inner [logic!]
	return: [integer!]
	/local result
][
	result: 0
	either outer [
		result: 1
	][
		if inner [result: 2]
	]
	result
]

print-line nested-if-statement true false
print-line nested-if-statement false true
print-line nested-if-statement false false
