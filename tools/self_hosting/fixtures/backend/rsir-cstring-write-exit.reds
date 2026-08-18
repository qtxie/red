Red/System [
	Title: "RSIR writable c-string literal fixture"
]

check: func [return: [integer!] /local text [c-string!]][
	text: "Red"
	text/1: #"B"
	either all [
		text/1 = #"B"
		text/2 = #"e"
		text/3 = #"d"
	][73][1]
]

quit check
