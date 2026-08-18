Red/System [
	Title: "RSIR fixed-width integer executable fixture"
]

#import [
	"msvcrt.dll" cdecl [
		quit: "exit" [status [integer!]]
	]
]

widen-signed: func [
	value [int8!]
	return: [int64!]
	/local medium [int32!]
][
	medium: value
	return medium
]

widen-unsigned: func [
	value [uint16!]
	return: [int32!]
][
	value
]

take-i32: func [
	value [int32!]
	return: [int32!]
][
	value
]

pass-u8: func [
	value [uint8!]
	return: [int32!]
][
	take-i32 value
]

cdecl-ret-i8: func [[cdecl] return: [int8!]][
	as int8! -2
]

callback-ret-i16: func [[callback] return: [int16!]][
	as int16! -300
]

width-score: func [
	return: [integer!]
	/local score [integer!]
][
	score: 0
	if (size? int8!) = 1 [score: score + 1]
	if (size? uint8!) = 1 [score: score + 1]
	if (size? int16!) = 2 [score: score + 1]
	if (size? uint16!) = 2 [score: score + 1]
	if (size? int32!) = 4 [score: score + 1]
	if (size? uint32!) = 4 [score: score + 1]
	if (size? int64!) = 8 [score: score + 1]
	if (size? uint64!) = 8 [score: score + 1]
	score
]

small-score: func [
	return: [integer!]
	/local score [integer!] i8 [int8!] u8 [uint8!]
		i16 [int16!] u16 [uint16!] i32 [int32!] u32 [uint32!]
][
	score: 0
	i8: (as int8! -100) * (as int8! 7)
	if i8 = (as int8! 68) [score: score + 1]
	u8: (as uint8! 250) + (as uint8! 10)
	if u8 = (as uint8! 4) [score: score + 1]
	i16: (as int16! -1024) >> 3
	if i16 = (as int16! -128) [score: score + 1]
	u16: (as uint16! 61440) >>> 8
	if u16 = (as uint16! 240) [score: score + 1]
	i32: (as int32! -123456) // (as int32! 100)
	if i32 = (as int32! 44) [score: score + 1]
	u32: (as uint32! EE6B2800h) / (as uint32! 100000)
	if u32 = (as uint32! 40000) [score: score + 1]
	u8: not (as uint8! 240)
	if u8 = (as uint8! 15) [score: score + 1]
	i8: as int8! -2
	if i8 < -1 [score: score + 1]
	u16: as uint16! 60000
	if u16 > 50000 [score: score + 1]
	score
]

wide-score: func [
	return: [integer!]
	/local score [integer!] i64 [int64!] u64 [uint64!]
][
	score: 0
	i64: (as int64! 0000000100000000h) + (as int64! 3)
	if i64 = (as int64! 0000000100000003h) [score: score + 1]
	i64: (as int64! 0000000500000008h) / (as int64! 3)
	if i64 = (as int64! 00000001AAAAAAADh) [score: score + 1]
	i64: (as int64! 0000000500000008h) % (as int64! 3)
	if i64 = (as int64! 1) [score: score + 1]
	i64: (as int64! -100) // (as int64! 7)
	if i64 = (as int64! 5) [score: score + 1]
	i64: (as int64! 1) << 33
	if i64 = (as int64! 0000000200000000h) [score: score + 1]
	i64: (as int64! 8000000000000000h) >> 63
	if i64 = (as int64! -1) [score: score + 1]
	u64: (as uint64! FFFFFFFFFFFFFFFFh) / (as uint64! 3)
	if u64 = (as uint64! 5555555555555555h) [score: score + 1]
	u64: (as uint64! F000000000000000h) >>> 60
	if u64 = (as uint64! 15) [score: score + 1]
	if (as uint64! FFFFFFFFFFFFFFFFh) > (as uint64! 7FFFFFFFFFFFFFFFh) [
		score: score + 1
	]
	score
]

conversion-score: func [
	return: [integer!]
	/local score [integer!] wide [int64!] medium [int32!] small [int8!]
][
	score: 0
	wide: widen-signed as int8! -2
	if wide = (as int64! -2) [score: score + 1]
	medium: widen-unsigned as uint16! 60000
	if medium = 60000 [score: score + 1]
	medium: pass-u8 as uint8! 250
	if medium = 250 [score: score + 1]
	small: as int8! 255
	if small = (as int8! -1) [score: score + 1]
	if (as int32! cdecl-ret-i8) = -2 [score: score + 1]
	if (as int32! callback-ret-i16) = -300 [score: score + 1]
	score
]

log-score: func [
	return: [integer!]
	/local score [integer!]
][
	score: 0
	if (log-b as byte! 128) = 7 [score: score + 1]
	if (log-b as int8! 64) = 6 [score: score + 1]
	if (log-b as uint8! 128) = 7 [score: score + 1]
	if (log-b as int16! 16384) = 14 [score: score + 1]
	if (log-b as uint16! 32768) = 15 [score: score + 1]
	if (log-b 40000000h) = 30 [score: score + 1]
	if (log-b as uint32! 80000000h) = 31 [score: score + 1]
	if (log-b as int64! 0000010000000000h) = 40 [score: score + 1]
	if (log-b as uint64! 8000000000000000h) = 63 [score: score + 1]
	score
]

abi-score: func [
	[cdecl]
	a [int8!] b [uint8!] c [int16!] d [uint16!]
	e [int32!] f [uint32!] g [int64!] h [uint64!]
	return: [integer!]
	/local score [integer!]
][
	score: 0
	if a = (as int8! -2) [score: score + 1]
	if b = (as uint8! 250) [score: score + 1]
	if c = (as int16! -300) [score: score + 1]
	if d = (as uint16! 60000) [score: score + 1]
	if e = (as int32! -123456) [score: score + 1]
	if f = (as uint32! FFFFFFFFh) [score: score + 1]
	if g = (as int64! -3) [score: score + 1]
	if h = (as uint64! FFFFFFFFFFFFFFFFh) [score: score + 1]
	score
]

main: func [
	return: [integer!]
	/local score [integer!]
][
	score: width-score
	score: score + small-score
	score: score + wide-score
	score: score + conversion-score
	score: score + log-score
	score: score + abi-score
		as int8! -2
		as uint8! 250
		as int16! -300
		as uint16! 60000
		as int32! -123456
		as uint32! FFFFFFFFh
		as int64! -3
		as uint64! FFFFFFFFFFFFFFFFh
	either score = 49 [73][score]
]

quit main
