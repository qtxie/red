Red/System [
	Title: "RSIR pointer DECLARE fixture"
]

#import [
	"msvcrt.dll" cdecl [
		process-exit: "exit" [status [integer!]]
	]
]

value: declare int-ptr!
link: declare ptr-ptr!

local-value: func [return: [integer!] /local value [int-ptr!]][
	value: declare int-ptr!
	value/value: 73
	value/value
]

pointer-depth: func [
	depth [integer!]
	return: [integer!]
	/local value [int-ptr!] result [integer!]
][
	value: declare int-ptr!
	value/value: depth
	either depth = 0 [
		1
	][
		result: pointer-depth (depth - 1)
		if value/value <> depth [return -1]
		result + 1
	]
]

local-link: func [
	return: [integer!]
	/local value [int-ptr!] link [ptr-ptr!] read-back [int-ptr!]
][
	value: declare int-ptr!
	link: declare ptr-ptr!
	value/value: 71
	link/value: as pointer! value
	read-back: as int-ptr! link/value
	read-back/value
]

main: func [
	return: [integer!]
	/local read-back [int-ptr!]
][
	value/value: 73
	if value/value <> 73 [return 1]
	if local-value <> 73 [return 2]
	if (pointer-depth 3) <> 4 [return 3]
	link/value: as pointer! value
	read-back: as int-ptr! link/value
	if read-back/value <> 73 [return 4]
	if local-link <> 71 [return 5]
	73
]

process-exit main
