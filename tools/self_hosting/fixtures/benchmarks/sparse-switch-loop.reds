Red/System [
	Title: "Generated-code sparse switch benchmark"
]

sparse-switch: func [value [integer!] return: [integer!]][
	switch value [
		-150000 [1]
		-140000 [2]
		-130000 [3]
		-120000 [4]
		-110000 [5]
		-100000 [6]
		-90000 [7]
		-80000 [8]
		-70000 [9]
		-60000 [10]
		-50000 [11]
		-40000 [12]
		-30000 [13]
		-20000 [14]
		-10000 [15]
		10000 [16]
		20000 [17]
		30000 [18]
		40000 [19]
		50000 [20]
		60000 [21]
		70000 [22]
		80000 [23]
		90000 [24]
		100000 [25]
		110000 [26]
		120000 [27]
		130000 [28]
		140000 [29]
		150000 [30]
		160000 [31]
		default [99]
	]
]

hot-sparse-switch-loop: func [
	iterations [integer!]
	return: [integer!]
	/local index checksum
][
	index: 0
	checksum: 0
	while [index < iterations][
		checksum: checksum + (sparse-switch -150000)
		checksum: checksum + (sparse-switch 10000)
		checksum: checksum + (sparse-switch 160000)
		checksum: checksum + (sparse-switch 0)
		index: index + 1
	]
	checksum
]

print-line hot-sparse-switch-loop 10000000
