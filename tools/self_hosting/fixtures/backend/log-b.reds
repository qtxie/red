Red/System [
	Title: "O2 log-b intrinsic fixture"
]

log-value: func [
	value [integer!]
	return: [integer!]
][
	log-b value
]

next-power-of-two: func [
	value [integer!]
	return: [integer!]
	/local result [integer!]
][
	result: 1 << log-b value
	if value <> result [result: result << 1]
	result
]

next-power-checksum: func [
	iterations [integer!]
	return: [integer!]
	/local index checksum value
][
	index: 0
	checksum: 0
	while [index < iterations][
		value: (index and 0000FFFFh) + 1
		checksum: checksum + next-power-of-two value
		index: index + 1
	]
	checksum
]

print-line either (log-value 1) = 0 [1][0]
print-line either (log-value 2) = 1 [1][0]
print-line either (log-value 3) = 1 [1][0]
print-line either (log-value 16) = 4 [1][0]
print-line either (log-value -1) = 31 [1][0]
print-line either (log-value 80000000h) = 31 [1][0]
print-line either (next-power-of-two 1) = 1 [1][0]
print-line either (next-power-of-two 2) = 2 [1][0]
print-line either (next-power-of-two 3) = 4 [1][0]
print-line either (next-power-of-two 31) = 32 [1][0]
print-line either (next-power-of-two 1025) = 2048 [1][0]
print-line either (next-power-of-two 32769) = 65536 [1][0]
print-line either (next-power-of-two 65536) = 65536 [1][0]
print-line either (next-power-checksum 1000) = 674475 [1][0]
