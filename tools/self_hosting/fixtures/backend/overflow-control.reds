Red/System [
	Title: "O2 overflow control-flow and flag dependency coverage"
]

checked-add: func [
	left [integer!]
	right [integer!]
	return: [integer!]
	/local value
][
	if overflow? [value: left + right][return 1]
	0
]

checked-subtract: func [
	left [integer!]
	right [integer!]
	return: [integer!]
	/local value
][
	if overflow? [value: left - right][return 1]
	0
]

checked-multiply: func [
	left [integer!]
	right [integer!]
	return: [integer!]
	/local value
][
	if overflow? [value: left * right][return 1]
	0
]

checked-shift-one: func [
	value [integer!]
	return: [integer!]
	/local result
][
	if overflow? [result: value << 1][return 1]
	0
]

checked-shift-thirty-one: func [
	value [integer!]
	return: [integer!]
	/local result
][
	if overflow? [result: value << 31][return 1]
	0
]

checked-divide: func [
	left [integer!]
	right [integer!]
	return: [integer!]
	/local value
][
	if overflow? [value: left / right][return 1]
	0
]

checked-modulo: func [
	left [integer!]
	right [integer!]
	return: [integer!]
	/local value
][
	if overflow? [value: left // right][return 1]
	0
]

checked-remainder: func [
	left [integer!]
	right [integer!]
	return: [integer!]
	/local value
][
	if overflow? [value: left % right][return 1]
	0
]

early-overflow: func [
	return: [integer!]
	/local value ignored flag
][
	value: 0
	flag: overflow? [
		value: value + 1
		ignored: 2147483647 + 1
		value: value + 100
	]
	if flag [
		if value = 1 [return 11]
	]
	-1
]

nested-overflow: func [
	outer-overflow [logic!]
	return: [integer!]
	/local value inner outer
][
	value: 2147483647
	inner: false
	outer: overflow? [
		inner: overflow? [value: value + 1]
		if outer-overflow [value: value + 1]
	]
	if outer [return 1]
	if inner [return 10]
	0
]

wrap-in-callee: func [
	value [integer!]
	return: [integer!]
][
	value + 1
]

callee-overflow-is-lexical: func [
	return: [integer!]
	/local value
][
	if overflow? [value: wrap-in-callee 2147483647][return 1]
	0
]

no-math-overflow: func [
	return: [integer!]
	/local value
][
	if overflow? [value: 5][return 1]
	0
]

print-line checked-add 2147483647 1
print-line checked-add 41 1
print-line checked-subtract -2147483648 1
print-line checked-subtract 10 5
print-line checked-multiply 46341 46341
print-line checked-multiply 46340 46340
print-line checked-shift-one 1073741823
print-line checked-shift-one 1073741824
print-line checked-shift-one -1073741824
print-line checked-shift-one -1073741825
print-line checked-shift-thirty-one -1
print-line checked-shift-thirty-one -2
print-line checked-divide -2147483648 -1
print-line checked-divide -2147483647 -1
print-line checked-modulo -2147483648 -1
print-line checked-remainder -2147483648 -1
print-line early-overflow
print-line nested-overflow false
print-line nested-overflow true
print-line callee-overflow-is-lexical
print-line no-math-overflow
