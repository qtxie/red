Red/System [
	Title: "RSIR exceptions linked executable fixture"
]

#import [
	"msvcrt.dll" cdecl [
		process-exit: "exit" [status [integer!]]
	]
]

raise: func [id [integer!]][throw id]

middle: func [id [integer!]][raise id]

local-catch?: func [return: [logic!]][
	system/thrown: 0
	catch 3 [throw 2]
	system/thrown = 2
]

deep-catch?: func [return: [logic!]][
	system/thrown: 0
	catch 9 [middle 7]
	system/thrown = 7
]

nested-catch?: func [return: [logic!]][
	system/thrown: 0
	catch 5 [
		catch 2 [throw 1]
		if system/thrown <> 1 [return false]
		system/thrown: 0
		throw 4
	]
	system/thrown = 4
]

mismatch: func [][catch 2 [throw 7]]

mismatch-catch?: func [return: [logic!]][
	system/thrown: 0
	catch 9 [mismatch]
	system/thrown = 7
]

catch-child: func [][throw 11]

catch-all-value: func [[catch] return: [integer!]][
	system/thrown: 0
	catch-child
	system/thrown
]

rethrow: func [[catch]][throw 13]

rethrow-catch?: func [return: [logic!]][
	system/thrown: 0
	catch 13 [rethrow]
	system/thrown = 13
]

leave-by-break: func [][
	loop 1 [catch 2 [catch 1 [break]]]
	throw 1
]

break-catch?: func [return: [logic!]][
	system/thrown: 0
	catch 1 [leave-by-break]
	system/thrown = 1
]

leave-by-continue: func [][
	loop 1 [catch 1 [continue]]
	throw 1
]

continue-catch?: func [return: [logic!]][
	system/thrown: 0
	catch 1 [leave-by-continue]
	system/thrown = 1
]

main: func [return: [integer!]][
	if not local-catch? [return 1]
	if not deep-catch? [return 2]
	if not nested-catch? [return 3]
	if not mismatch-catch? [return 4]
	if catch-all-value <> 11 [return 5]
	if not rethrow-catch? [return 6]
	if not break-catch? [return 7]
	if not continue-catch? [return 8]
	system/thrown: 42
	if system/thrown <> 42 [return 9]
	73
]

system/thrown: 0
catch 1 [raise 1]
if system/thrown <> 1 [process-exit 10]
system/thrown: 0
process-exit main
