Red/System [
	Title: "Generated-code dense switch benchmark"
]

dense-switch: func [value [integer!] return: [integer!]][
	switch value [
		10 [1]
		12 [2]
		14 [3]
		16 [4]
		18 [5]
		20 [6]
		22 [7]
		24 [8]
		26 [9]
		28 [10]
		30 [11]
		32 [12]
		34 [13]
		36 [14]
		38 [15]
		40 [16]
		42 [17]
		44 [18]
		46 [19]
		48 [20]
		50 [21]
		52 [22]
		54 [23]
		56 [24]
		58 [25]
		60 [26]
		62 [27]
		64 [28]
		66 [29]
		68 [30]
		70 [31]
		72 [32]
		default [99]
	]
]

hot-dense-switch-loop: func [
	iterations [integer!]
	return: [integer!]
	/local index checksum
][
	index: 0
	checksum: 0
	while [index < iterations][
		checksum: checksum + (dense-switch 10)
		checksum: checksum + (dense-switch 40)
		checksum: checksum + (dense-switch 72)
		checksum: checksum + (dense-switch 11)
		index: index + 1
	]
	checksum
]

print-line hot-dense-switch-loop 10000000
