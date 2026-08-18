Red/System [
	Title: "RSIR Win64 stack argument slot fixture"
]

#import [
	"msvcrt.dll" cdecl [
		process-exit: "exit" [status [integer!]]
	]
]

seed-slot: func [
	a [integer!] b [integer!] c [integer!] d [integer!]
	e [int64!]
	return: [int64!]
][e]

read-slot: func [
	a [integer!] b [integer!] c [integer!] d [integer!]
	e [integer!]
	return: [int64!]
	/local frame [int-ptr!] slot [pointer! [int64!]]
][
	frame: system/stack/frame
	slot: as pointer! [int64!] (frame + 12)
	slot/1
]

main: func [
	return: [integer!]
	/local seed value [int64!]
][
	seed: seed-slot 1 2 3 4 #i64-4294967296
	value: read-slot 1 2 3 4 0
	either all [
		seed = #i64-4294967296
		value = (as int64! 0)
	][73][1]
]

process-exit main
