Red/System [
	Title: "RSIR case/switch linked executable fixture"
]

#import [
	"msvcrt.dll" cdecl [
		quit: "exit" [status [integer!]]
	]
]

choose: func [
	value [integer!]
	return: [integer!]
][
	switch value [
		1 [11]
		3 [
			case [
				value = 2 [22]
				true [73]
			]
		]
		default [99]
	]
]

quit choose 3
