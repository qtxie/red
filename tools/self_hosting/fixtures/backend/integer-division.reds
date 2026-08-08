Red/System [
	Title: "O2 signed integer division and modulus fixture"
]

divide-values: func [
	left [integer!]
	right [integer!]
	return: [integer!]
][
	left / right
]

modulo-values: func [
	left [integer!]
	right [integer!]
	return: [integer!]
][
	left // right
]

remainder-values: func [
	left [integer!]
	right [integer!]
	return: [integer!]
][
	left % right
]

mixed-divisions: func [
	value [integer!]
	divisor [integer!]
	modulus [integer!]
	return: [integer!]
	/local quotient residue
][
	quotient: value / divisor
	residue: value // modulus
	quotient + residue
]

leap-year-check: func [
	year [integer!]
	return: [logic!]
][
	all [
		(year and 3) = 0
		any [
			year % 100 <> 0
			year % 400 = 0
		]
	]
]

print-line either (divide-values 17 5) = 3 [1][0]
print-line either (divide-values -17 5) = -3 [1][0]
print-line either (divide-values 17 -5) = -3 [1][0]
print-line either (divide-values -17 -5) = 3 [1][0]
print-line either (divide-values 7 1) = 7 [1][0]
print-line either (divide-values 80000000h 1) = 80000000h [1][0]
print-line either (modulo-values 17 5) = 2 [1][0]
print-line either (modulo-values -17 5) = 3 [1][0]
print-line either (modulo-values 17 -5) = 2 [1][0]
print-line either (modulo-values -17 -5) = 3 [1][0]
print-line either (remainder-values -17 5) = -2 [1][0]
print-line either (remainder-values 17 -5) = 2 [1][0]
print-line either (mixed-divisions -17 5 5) = 0 [1][0]
print-line either leap-year-check 2000 [1][0]
print-line either not leap-year-check 1900 [1][0]
print-line either leap-year-check 2024 [1][0]
print-line either not leap-year-check 2023 [1][0]
