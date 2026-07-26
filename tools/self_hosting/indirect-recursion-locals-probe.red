Red [
	Title: "Compiled indirect recursion locals probe"
]

holder: context [
	depth: 0

	dispatch: does [worker]

	worker: has [saved-depth nested][
		saved-depth: depth
		nested: either depth < 3 [
			depth: depth + 1
			dispatch
		][0]
		saved-depth + nested + 1
	]
]

result: holder/dispatch
print ["indirect recursion result:" result]
quit/return either result = 10 [0][1]
