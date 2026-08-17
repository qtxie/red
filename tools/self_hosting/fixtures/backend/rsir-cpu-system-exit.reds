Red/System [
	Title: "RSIR system/pc and system/cpu linked executable fixture"
]

#import [
	"msvcrt.dll" cdecl [
		process-exit: "exit" [status [integer!]]
	]
]

program-counter-test: func [
	return: [logic!]
	/local first second [byte-ptr!]
][
	first: system/pc
	second: system/pc
	all [first <> null second <> null first <> second]
]

register-test: func [
	return: [logic!]
	/local value [int-ptr!]
][
	system/cpu/rcx: as int-ptr! 42
	value: system/cpu/rcx
	value = as int-ptr! 42
]

save-all-test: func [
	return: [logic!]
	/local before after [int-ptr!]
][
	before: system/cpu/rax
	system/stack/push-all
	system/cpu/rax: as int-ptr! 123
	system/stack/pop-all
	after: system/cpu/rax
	before = after
]

overflow-test: func [
	return: [integer!]
	/local x result [integer!] overflowed? [logic!]
][
	x: 2147483647
	result: x + 1
	overflowed?: system/cpu/overflow?
	if not overflowed? [return 1]

	x: -2000000000
	result: x - 2000000000
	overflowed?: system/cpu/overflow?
	if not overflowed? [return 2]

	x: 1000
	result: x * 2000
	overflowed?: system/cpu/overflow?
	if overflowed? [return 3]

	x: -2147483648
	result: x * -1
	overflowed?: system/cpu/overflow?
	if not overflowed? [return 4]

	x: 2147483647
	result: x / -1
	overflowed?: system/cpu/overflow?
	if overflowed? [return 5]

	73
]

main: func [return: [integer!]][
	either all [
		program-counter-test
		register-test
		save-all-test
		overflow-test = 73
	][73][1]
]

process-exit main
