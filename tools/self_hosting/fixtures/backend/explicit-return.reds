Red/System [
	Title: "O2 explicit return and exit control-flow coverage"
]

early-return: func [
	value [integer!]
	return: [integer!]
][
	if value < 0 [return -11]
	if value = 0 [return 0]
	value + 11
]

direct-return: func [
	return: [integer!]
][
	return 42
]

dead-after-return: func [
	return: [integer!]
][
	return 7
	99
]

return-from-while: func [
	limit [integer!]
	return: [integer!]
	/local i
][
	i: 0
	while [i < limit][
		if i = 3 [return i]
		i: i + 1
	]
	-1
]

void-exit: func [value [integer!]][
	if value = 0 [exit]
	print-line value
]

return-from-switch: func [
	value [integer!]
	return: [integer!]
][
	switch value [
		0 [return 10]
		1 [return 20]
		2 [return 30]
		3 [return 40]
		4 [return 50]
		default [return 60]
	]
]

switch-return-or-value: func [
	value [integer!]
	return: [integer!]
][
	switch value [
		0 [return 100]
		1 [value + 10]
		2 [value + 20]
		3 [value + 30]
		4 [value + 40]
		default [value + 1]
	]
]

either-return-or-value: func [
	value [integer!]
	return: [integer!]
][
	either value < 0 [return -5][value + 5]
]

either-both-return: func [
	value [integer!]
	return: [integer!]
][
	either value = 0 [return 70][return 80]
]

print-line early-return -1
print-line early-return 0
print-line early-return 5
print-line direct-return
print-line dead-after-return
print-line return-from-while 8
print-line return-from-while 2
void-exit 0
void-exit 7
print-line return-from-switch 0
print-line return-from-switch 2
print-line return-from-switch 7
print-line switch-return-or-value 0
print-line switch-return-or-value 8
print-line either-return-or-value -1
print-line either-return-or-value 4
print-line either-both-return 0
print-line either-both-return 1
