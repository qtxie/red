Red/System [
	Title: "O2 resolver call without an inline registry"
]

red: context [
	resolve-series: func [
		handle [integer!]
		return: [int-ptr!]
	][
		either handle = 7 [as int-ptr! 4000h][null]
	]
]

call-resolve-series: func [
	handle [integer!]
	return: [int-ptr!]
][
	red/resolve-series handle
]

print-line either null? call-resolve-series 1 [0][1]
print-line either null? call-resolve-series 7 [0][1]
