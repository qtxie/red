Red/System [
	Title: "RSIR protected data fixture"
]

#import [
	"msvcrt.dll" cdecl [
		process-exit: "exit" [status [integer!]]
	]
]

double: func [value [integer!] return: [integer!]][value * 2]
triple: func [value [integer!] return: [integer!]][value * 3]

int-fn!: alias function! [value [integer!] return: [integer!]]

nums: protect [10 20 30 40]
floats: protect [1.5 2.5 3.5]
message: protect "protected"
bytes: protect #{C0FFEE}
labels: protect ["alpha" "beta"]
functions: protect [:double :triple]
cast: protect as byte-ptr! "AB"
truth: protect true
typed: protect as int32! 7
RATE: protect 60
HALF: protect 0.5
LETTER: protect #"Z"

table: [1 RATE 3]

sum: func [return: [integer!] /local index total [integer!]][
	index: 1
	total: 0
	while [index <= 4][
		total: total + nums/index
		index: index + 1
	]
	total
]

main: func [return: [integer!] /local score [integer!] operation [int-fn!]][
	score: 0
	if (size? nums) = 4 [score: score + 1]
	if nums/2 = 20 [score: score + 1]
	if sum = 100 [score: score + 1]
	if floats/2 = 2.5 [score: score + 1]
	if message/1 = #"p" [score: score + 1]
	if bytes/1 = #"^(C0)" [score: score + 1]
	if bytes/2 = #"^(FF)" [score: score + 1]
	if bytes/3 = #"^(EE)" [score: score + 1]
	if labels/1/1 = #"a" [score: score + 1]
	if labels/2/1 = #"b" [score: score + 1]
	operation: as int-fn! functions/1
	if (operation 2) = 4 [score: score + 1]
	operation: as int-fn! functions/2
	if (operation 2) = 6 [score: score + 1]
	if cast/1 = #"A" [score: score + 1]
	if cast/2 = #"B" [score: score + 1]
	if RATE = 60 [score: score + 1]
	if HALF = 0.5 [score: score + 1]
	if LETTER = #"Z" [score: score + 1]
	if table/2 = 60 [score: score + 1]
	if truth [score: score + 1]
	if typed = 7 [score: score + 1]
	either score = 20 [73][score]
]

process-exit main
