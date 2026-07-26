Red/System [
	Title: "Linked Linux IA-32 self-hosting fixture"
]

#import [
	"libc.so.6" cdecl [
		libc-exit: "exit" [
			status [integer!]
		]
	]
]

libc-exit 0
