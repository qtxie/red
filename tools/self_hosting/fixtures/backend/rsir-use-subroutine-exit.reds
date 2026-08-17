Red/System [
	Title: "RSIR USE and subroutine linked executable fixture"
]

#import [
	"msvcrt.dll" cdecl [
		process-exit: "exit" [status [integer!]]
	]
]

outside: 73

compute: func [return: [integer!] /local value [integer!] step [subroutine!]][
	value: 2
	step: [value: value + 3]
	step
	use [outer [integer!]][
		outer: 17
		use [inner [integer!]][
			inner: 51
			value: value + outer + inner
		]
	]
	use [outer [integer!]][outer: 0 value: value + outer]
	value
]

early: func [flag [logic!] return: [integer!] /local stop [subroutine!]][
	stop: [if flag [return 73]]
	stop
	0
]

chain: func [return: [integer!] /local value [integer!] first-step second-step [subroutine!]][
	value: 1
	first-step: [value: value + 2 second-step]
	second-step: [value: value + 4]
	first-step
	value
]

subroutine-value: func [return: [integer!] /local answer [subroutine!]][
	answer: [36 + 37]
	answer
]

use-scope: func [return: [integer!]][
	use [outside [integer!]][outside: 1]
	outside
]

main: func [return: [integer!] /local score [integer!] value [integer!]][
	score: 0
	value: compute
	if value = 73 [score: score + 1]
	value: early true
	if value = 73 [score: score + 1]
	value: early false
	if value = 0 [score: score + 1]
	value: chain
	if value = 7 [score: score + 1]
	value: subroutine-value
	if value = 73 [score: score + 1]
	value: use-scope
	if value = 73 [score: score + 1]
	either score = 6 [73][score]
]

process-exit main
