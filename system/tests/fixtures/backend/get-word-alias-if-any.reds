Red/System [
	Title: "O2 get-word function alias in IF/ANY"
]

callback!: alias function! [value [integer!] return: [integer!]]

identity: func [value [integer!] return: [integer!]][
	value
]

dummy: 0

has-callback?: func [enabled? [logic!] return: [logic!] /local do-scan [callback!]][
	do-scan: as callback! :dummy
	if any [enabled? :do-scan <> null][
		return yes
	]
	no
]

either has-callback? no [quit 0][quit 1]
