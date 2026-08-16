Red/System [
	Title: "RSIR literal array fixture"
]

#import [
	"msvcrt.dll" cdecl [
		process-exit: "exit" [status [integer!]]
	]
]

values: [10 20 30 40]
floats: [1.5 2.5 3.5]
bytes: #{09080706}
message: "Red"
labels: ["north" "south"]

double: func [value [integer!] return: [integer!]][value * 2]
triple: func [value [integer!] return: [integer!]][value * 3]

functions: [:double :triple]
entry: :double

local-bytes: func [
	return: [byte-ptr!]
	/local buffer [byte-ptr!]
][
	buffer: #{030405}
	buffer
]

main: func [
	return: [integer!]
	/local score index [integer!] integers [int-ptr!] buffer [byte-ptr!]
][
	score: 0
	if (size? values) = 4 [score: score + 1]
	if values/2 = 20 [score: score + 1]
	values/2: 25
	if values/2 = 25 [score: score + 1]
	index: 3
	if values/index = 30 [score: score + 1]
	integers: values
	if integers/4 = 40 [score: score + 1]

	if (size? floats) = 3 [score: score + 1]
	if floats/1 = 1.5 [score: score + 1]
	floats/2: 4.5
	if floats/2 = 4.5 [score: score + 1]

	if (size? bytes) = 4 [score: score + 1]
	if bytes/1 = #"^(09)" [score: score + 1]
	if bytes/4 = #"^(06)" [score: score + 1]
	buffer: local-bytes
	if buffer/1 = #"^(03)" [score: score + 1]
	if buffer/3 = #"^(05)" [score: score + 1]
	if message/2 = #"e" [score: score + 1]
	if labels/1/1 = #"n" [score: score + 1]
	if labels/2/1 = #"s" [score: score + 1]
	if functions/1 = :double [score: score + 1]
	if all [functions/2 = :triple entry = :double][score: score + 1]

	either score = 18 [73][score]
]

process-exit main
