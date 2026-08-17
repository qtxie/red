Red/System [
	Title: "RSIR system/stack linked executable fixture"
]

wide-ptr!: alias pointer! [int64!]

#import [
	"msvcrt.dll" cdecl [
		process-exit: "exit" [status [integer!]]
	]
]

increment: func [value [integer!] return: [integer!]][value + 1]

automatic-allocation: func [
	return: [integer!]
	/local memory [wide-ptr!]
][
	memory: as wide-ptr! system/stack/allocate 3
	memory/1: as int64! 73
	73
]

stack-pointers?: func [
	return: [logic!]
	/local top frame [int-ptr!]
][
	top: system/stack/top
	frame: system/stack/frame
	if any [top = null frame = null top = frame][return false]
	system/stack/frame: frame
	frame = system/stack/frame
]

allocation-test: func [
	return: [integer!]
	/local
		slots result [integer!]
		saved [int-ptr!]
		memory [wide-ptr!]
		integers [int-ptr!]
][
	slots: 4
	saved: system/stack/top
	memory: as wide-ptr! system/stack/allocate/zero slots
	if any [
		memory/1 <> (as int64! 0)
		memory/2 <> (as int64! 0)
		memory/3 <> (as int64! 0)
		memory/4 <> (as int64! 0)
	][return 1]
	integers: as int-ptr! memory
	integers/1: 41
	result: increment integers/1
	if any [result <> 42 integers/1 <> 41][return 2]
	system/stack/free slots
	if system/stack/top <> saved [return 3]
	73
]

automatic-free?: func [
	return: [logic!]
	/local before after [int-ptr!]
][
	before: system/stack/top
	if automatic-allocation <> 73 [return false]
	after: system/stack/top
	before = after
]

alignment-test: func [
	return: [integer!]
	/local before saved aligned [int-ptr!] value [integer!]
][
	before: system/stack/top
	push 73
	saved: system/stack/align
	aligned: system/stack/top
	if aligned <> (saved - 2) [return 1]
	system/stack/top: saved
	value: pop
	if any [value <> 73 system/stack/top <> before][return 2]
	73
]

save-all-test: func [
	return: [integer!]
	/local before during after [int-ptr!] result [integer!]
][
	before: system/stack/top
	system/stack/push-all
	during: system/stack/top
	result: increment 40
	system/stack/pop-all
	after: system/stack/top
	if any [during = before after <> before result <> 41][return 1]
	73
]

main: func [return: [integer!]][
	either all [
		stack-pointers?
		allocation-test = 73
		automatic-free?
		alignment-test = 73
		save-all-test = 73
	][73][1]
]

process-exit main
