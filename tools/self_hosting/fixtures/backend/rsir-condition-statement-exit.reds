Red/System [
	Title: "RSIR ANY/ALL statement linked executable fixture"
]

#import [
	"msvcrt.dll" cdecl [
		process-exit: "exit" [status [integer!]]
	]
]

touches: 0

touch: func [][
	touches: touches + 1
]

main: func [return: [integer!]][
	touches: 0
	if not any [true touch] [return 1]
	if touches <> 0 [return 2]

	touches: 0
	if all [false touch] [return 3]
	if touches <> 0 [return 4]

	touches: 0
	if not all [true touch] [return 5]
	if touches <> 1 [return 6]

	touches: 0
	if any [false touch] [return 7]
	if touches <> 1 [return 8]

	touches: 0
	if not all [true touch true] [return 9]
	if touches <> 1 [return 10]

	touches: 0
	if not any [false touch true] [return 11]
	if touches <> 1 [return 12]
	73
]

process-exit main
