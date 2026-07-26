Red/System [
	Title: "Linked Windows IA-32 self-hosting fixture"
	]

#import [
	"kernel32.dll" stdcall [
		ExitProcess: "ExitProcess" [
			status [integer!]
		]
	]
]

ExitProcess 0
