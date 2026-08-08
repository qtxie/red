Red/System [
	Title: "O2 x64 small dense switch coverage"
]

small-dense-switch: func [
	value [integer!]
	return: [integer!]
][
	switch value [
		2 [16]
		3 [20]
		4 [32]
		5 [48]
		6 [64]
		default [0]
	]
]

print-line either (small-dense-switch 1) = 0 [1][0]
print-line either (small-dense-switch 2) = 16 [1][0]
print-line either (small-dense-switch 4) = 32 [1][0]
print-line either (small-dense-switch 6) = 64 [1][0]
print-line either (small-dense-switch 7) = 0 [1][0]
