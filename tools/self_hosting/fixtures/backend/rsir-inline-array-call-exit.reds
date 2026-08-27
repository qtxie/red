Red/System [
	Title: "RSIR inline array call fixture"
]

#import [
	"msvcrt.dll" cdecl [
		process-exit: "exit" [status [integer!]]
	]
]

first-character?: func [
	values [pointer! [c-string!]]
	return: [logic!]
	/local text [byte-ptr!]
][
	text: as byte-ptr! values/1
	text/1 = #"J"
]

months: ["January" "February"]

main: func [return: [integer!]][
	either first-character? months [73][1]
]

process-exit main
