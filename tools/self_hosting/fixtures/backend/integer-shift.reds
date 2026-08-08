Red/System [
	Title: "O2 integer shift fixture"
]

shift-left-7: func [
	value [integer!]
	return: [integer!]
][
	value << 7
]

shift-right-signed-3: func [
	value [integer!]
	return: [integer!]
][
	value >> 3
]

shift-right-unsigned-1: func [
	value [integer!]
	return: [integer!]
][
	value -** 1
]

shift-left-variable: func [
	value [integer!]
	count [integer!]
	return: [integer!]
][
	value << count
]

shift-right-signed-variable: func [
	value [integer!]
	count [integer!]
	return: [integer!]
][
	value >> count
]

shift-right-unsigned-variable: func [
	value [integer!]
	count [integer!]
	return: [integer!]
][
	value -** count
]

print-line either (shift-left-7 5) = 640 [1][0]
print-line either (shift-left-7 40000000h) = 00000000h [1][0]
print-line either (shift-right-signed-3 -1024) = -128 [1][0]
print-line either (shift-right-unsigned-1 -1) = 2147483647 [1][0]
print-line either (shift-right-unsigned-1 80000000h) = 40000000h [1][0]
print-line either (shift-left-variable 3 4) = 48 [1][0]
print-line either (shift-left-variable 3 36) = 48 [1][0]
print-line either (shift-left-variable 3 -28) = 48 [1][0]
print-line either (shift-right-signed-variable -1024 3) = -128 [1][0]
print-line either (shift-right-unsigned-variable -1 1) = 2147483647 [1][0]
