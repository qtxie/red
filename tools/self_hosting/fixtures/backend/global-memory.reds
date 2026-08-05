Red/System [
	Title: "O2 RIP-relative global memory and relocation coverage"
]

global-scalar: 40
global-pointer: declare pointer! [integer!]
global-float: 0.0

bump-global: func [
	delta [integer!]
	return: [integer!]
][
	global-scalar: global-scalar + delta
	global-scalar
]

pointer-global-roundtrip: func [
	value [pointer! [integer!]]
	return: [pointer! [integer!]]
][
	global-pointer: value
	global-pointer
]

float-global-roundtrip: func [
	value [float!]
	return: [float!]
][
	global-float: value
	global-float
]

global-pointer: :global-scalar
print-line bump-global 2
result-pointer: pointer-global-roundtrip global-pointer
print-line result-pointer/value
print-line float-global-roundtrip 3.5
