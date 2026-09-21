Red/System [
	Title: "Standalone toolchain shared-library loader"
]

;-- Calls the export back through the DLL built from library.reds. Compiled and
;-- run by the toolchain under test, so the hermetic suite needs no host loader.

#import [
	"toolchain-library.dll" cdecl [
		toolchain-answer: "toolchain-answer" [return: [integer!]]
	]
]

print toolchain-answer
