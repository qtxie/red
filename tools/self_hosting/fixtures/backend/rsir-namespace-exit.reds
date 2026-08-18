Red/System [
	Title: "RSIR namespace executable fixture"
]

#import [
	"msvcrt.dll" cdecl [
		process-exit: "exit" [status [integer!]]
	]
]

value: 10

first: context [
	value: 20
	slot: 21

	read: func [return: [integer!]][value]
	read-root: func [return: [integer!]][system/words/value]
	write-root: func [][system/words/value: 11]
]

second: context [
	value: 30
	slot: 31
]

with [second first][
	read-selected: func [return: [integer!]][value]
	write-selected: func [][slot: 32]
]

with first [
	under-with: context [
		value: 60
		read: func [return: [integer!]][value]
	]
]

outer: context [
	value: 40
	inner: context [
		value: 50
		read: func [return: [integer!]][value]
		read-parent: func [return: [integer!]][outer/value]
	]
]

main: func [return: [integer!]][
	if value <> 10 [return 1]
	if first/read <> 20 [return 2]
	if first/read-root <> 10 [return 3]
	if read-selected <> 30 [return 4]

	write-selected
	if second/slot <> 32 [return 5]
	if first/slot <> 21 [return 6]
	if value <> 10 [return 7]

	first/write-root
	if value <> 11 [return 8]
	if first/value <> 20 [return 9]
	if outer/inner/read <> 50 [return 10]
	if outer/inner/read-parent <> 40 [return 11]
	if under-with/read <> 60 [return 12]
	if first/value <> 20 [return 13]
	73
]

process-exit main
