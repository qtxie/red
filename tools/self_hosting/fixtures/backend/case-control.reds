Red/System [
	Title: "O2 case control-flow and return coverage"
]

classify: func [
	value [integer!]
	return: [integer!]
][
	case [
		value < 0 [-1]
		value = 0 [0]
		true [1]
	]
]

case-return-or-value: func [
	value [integer!]
	return: [integer!]
][
	case [
		value < 0 [return -10]
		value = 0 [0]
		true [value + 10]
	]
]

case-all-return: func [
	value [integer!]
	return: [integer!]
][
	case [
		value = 1 [return 10]
		true [return 20]
	]
]

nested-case: func [
	value [integer!]
	return: [integer!]
][
	case [
		value < 0 [
			case [
				value < -10 [-2]
				true [-1]
			]
		]
		true [2]
	]
]

print-line classify -3
print-line classify 0
print-line classify 3
print-line case-return-or-value -1
print-line case-return-or-value 0
print-line case-return-or-value 5
print-line case-all-return 1
print-line case-all-return 2
print-line nested-case -20
print-line nested-case -2
print-line nested-case 2
