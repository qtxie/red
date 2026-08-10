Red/System [
	Title: "O2 unsigned byte overflow coverage"
]

checked-byte-add: func [
	left [byte!]
	right [byte!]
	return: [integer!]
	/local value [byte!]
][
	if overflow? [value: left + right][return 1]
	0
]

checked-byte-subtract: func [
	left [byte!]
	right [byte!]
	return: [integer!]
	/local value [byte!]
][
	if overflow? [value: left - right][return 1]
	0
]

checked-byte-multiply: func [
	left [byte!]
	right [byte!]
	return: [integer!]
	/local value [byte!]
][
	if overflow? [value: left * right][return 1]
	0
]

checked-byte-shift-seven: func [
	value [byte!]
	return: [integer!]
	/local result [byte!]
][
	if overflow? [result: value << 7][return 1]
	0
]

checked-byte-shift-four: func [
	value [byte!]
	return: [integer!]
	/local result [byte!]
][
	if overflow? [result: value << 4][return 1]
	0
]

print-line checked-byte-add #"^(FF)" #"^(01)"
print-line checked-byte-add #"^(7F)" #"^(01)"
print-line checked-byte-add #"^(FE)" #"^(01)"
print-line checked-byte-subtract #"^(00)" #"^(01)"
print-line checked-byte-subtract #"^(0A)" #"^(05)"
print-line checked-byte-multiply #"^(10)" #"^(10)"
print-line checked-byte-multiply #"^(0F)" #"^(11)"
print-line checked-byte-shift-seven #"^(01)"
print-line checked-byte-shift-seven #"^(02)"
print-line checked-byte-shift-four #"^(0F)"
print-line checked-byte-shift-four #"^(10)"
