Red/System [
	Title: "RSIR scalar floating-point executable fixture"
]

#import [
	"msvcrt.dll" cdecl [
		process-exit: "exit" [status [integer!]]
		cosine: "cos" [value [float!] return: [float!]]
	]
]

global-wide: 6.25
global-single: as float32! 3.5

return-wide: func [value [float!] return: [float!]][value]

return-single: func [value [float32!] return: [float32!]][value]

take-single: func [value [float32!] return: [float32!]][value]

wide-score: func [
	return: [integer!]
	/local score [integer!] a [float!] b [float!] nan [float!]
][
	score: 0
	a: 7.5
	b: 2.0
	if (a + b) = 9.5 [score: score + 1]
	if (a - b) = 5.5 [score: score + 1]
	if (a * b) = 15.0 [score: score + 1]
	if (a / b) = 3.75 [score: score + 1]
	if a = 7.5 [score: score + 1]
	if a <> b [score: score + 1]
	if a > b [score: score + 1]
	if b < a [score: score + 1]
	if a >= 7.5 [score: score + 1]
	if b <= 2.0 [score: score + 1]
	nan: 0.0 / 0.0
	if nan <> nan [score: score + 1]
	either nan = nan [score: score][score: score + 1]
	either nan < nan [score: score][score: score + 1]
	either nan > nan [score: score][score: score + 1]
	either nan <= nan [score: score][score: score + 1]
	either nan >= nan [score: score][score: score + 1]
	score
]

single-score: func [
	return: [integer!]
	/local score [integer!] a [float32!] b [float32!] nan [float32!]
][
	score: 0
	a: as float32! 7.5
	b: as float32! 2.0
	if (a + b) = (as float32! 9.5) [score: score + 1]
	if (a - b) = (as float32! 5.5) [score: score + 1]
	if (a * b) = (as float32! 15.0) [score: score + 1]
	if (a / b) = (as float32! 3.75) [score: score + 1]
	if a > b [score: score + 1]
	nan: as float32! (0.0 / 0.0)
	if nan <> nan [score: score + 1]
	either nan = nan [score: score][score: score + 1]
	either nan < nan [score: score][score: score + 1]
	either nan > nan [score: score][score: score + 1]
	either nan <= nan [score: score][score: score + 1]
	either nan >= nan [score: score][score: score + 1]
	score
]

cast-score: func [
	return: [integer!]
	/local score value bits [integer!] wide [float!] single [float32!]
][
	score: 0
	wide: as float! 42
	if wide = 42.0 [score: score + 1]
	single: as float32! 43
	if single = (as float32! 43.0) [score: score + 1]
	value: as integer! 44.75
	if value = 44 [score: score + 1]
	value: as integer! -45.75
	if value = -45 [score: score + 1]
	single: as float32! 46.5
	wide: as float! single
	if wide = 46.5 [score: score + 1]
	wide: 47.5
	single: as float32! wide
	if single = (as float32! 47.5) [score: score + 1]
	single: as float32! keep 1069547520
	bits: as integer! keep single
	if bits = 1069547520 [score: score + 1]
	if (take-single 48.5) = (as float32! 48.5) [score: score + 1]
	score
]

mixed-abi-score: func [
	[cdecl]
	a [integer!] b [float!] c [float32!] d [integer!]
	e [float!] f [float32!] g [integer!] h [float!]
	return: [integer!]
	/local score [integer!]
][
	score: 0
	if a = 1 [score: score + 1]
	if b = 2.5 [score: score + 1]
	if c = (as float32! 3.5) [score: score + 1]
	if d = 4 [score: score + 1]
	if e = 5.5 [score: score + 1]
	if f = (as float32! 6.5) [score: score + 1]
	if g = 7 [score: score + 1]
	if h = 8.5 [score: score + 1]
	score
]

global-score: func [return: [integer!] /local score [integer!]][
	score: 0
	if global-wide = 6.25 [score: score + 1]
	if global-single = (as float32! 3.5) [score: score + 1]
	global-wide: global-wide + 1.0
	if global-wide = 7.25 [score: score + 1]
	global-single: global-single + (as float32! 1.0)
	if global-single = (as float32! 4.5) [score: score + 1]
	score
]

main: func [return: [integer!] /local score [integer!]][
	score: wide-score
	score: score + single-score
	score: score + cast-score
	score: score + mixed-abi-score
		1 2.5 (as float32! 3.5) 4 5.5 (as float32! 6.5) 7 8.5
	score: score + global-score
	if (return-wide 9.25) = 9.25 [score: score + 1]
	if (return-single as float32! 10.25) = (as float32! 10.25) [
		score: score + 1
	]
	if (cosine 0.0) = 1.0 [score: score + 1]
	either score = 50 [73][score]
]

process-exit main
