Red/System [
	Title: "RSIR overflow? linked executable fixture"
]

#import [
	"msvcrt.dll" cdecl [
		process-exit: "exit" [status [integer!]]
	]
]

overflows-internally: func [return: [integer!]][
	2147483647 + 1
]

basic-tests: func [return: [logic!] /local n [integer!]][
	n: 0
	if overflow? [n: n][return false]
	if overflow? [n: 1 + 1][return false]
	if overflow? [n: 100 * 200][return false]
	if overflow? [n: 1000 - 500][return false]
	if overflow? [n: 1000 / 5][return false]
	n: 2147483647
	if overflow? [n: n + 0][return false]
	true
]

signed-tests: func [return: [logic!] /local n [integer!]][
	n: 0
	if overflow? [n: 2147483647 + 0][return false]
	if not overflow? [n: 2147483647 + 1][return false]
	if overflow? [n: -2147483648 - 0][return false]
	if not overflow? [n: -2147483648 - 1][return false]
	if overflow? [n: 46340 * 46340][return false]
	if not overflow? [n: 46341 * 46341][return false]
	if not overflow? [n: -2147483648 * -1][return false]
	true
]

narrow-tests: func [
	return: [logic!]
	/local b [byte!] by [byte!] s8 [int8!] s16 [int16!] u32 [uint32!]
][
	b: as byte! 255
	by: as byte! 1
	s8: as int8! 127
	s16: as int16! 32767
	if not overflow? [b: b + by][return false]
	b: as byte! 127
	if overflow? [b: b + by][return false]
	b: as byte! 0
	if not overflow? [b: b - by][return false]
	b: as byte! 10
	if overflow? [b: b - (as byte! 5)][return false]
	b: as byte! 20
	if not overflow? [b: b * b][return false]
	b: as byte! 10
	if overflow? [b: b * (as byte! 20)][return false]
	if not overflow? [s8: s8 + (as int8! 1)][return false]
	if not overflow? [s16: s16 + (as int16! 1)][return false]
	u32: as uint32! FFFFFFFFh
	if not overflow? [u32: u32 * (as uint32! 2)][return false]
	u32: as uint32! 100
	if overflow? [u32: u32 * (as uint32! 200)][return false]
	true
]

shift-tests: func [
	return: [logic!]
	/local n [integer!] count [integer!] b [byte!] s8 [int8!]
][
	n: 1
	b: as byte! 1
	if overflow? [n: n << 30][return false]
	n: 1
	if not overflow? [n: n << 31][return false]
	n: 1073741823
	if overflow? [n: n << 1][return false]
	n: 1073741824
	if not overflow? [n: n << 1][return false]
	n: -1
	if overflow? [n: n << 31][return false]
	n: -2
	if not overflow? [n: n << 31][return false]
	if overflow? [b: b << 7][return false]
	b: as byte! 2
	if not overflow? [b: b << 7][return false]
	s8: as int8! 1
	if overflow? [s8: s8 << 6][return false]
	s8: as int8! 1
	if not overflow? [s8: s8 << 7][return false]
	s8: as int8! -1
	if overflow? [s8: s8 << 7][return false]
	s8: as int8! -2
	if not overflow? [s8: s8 << 7][return false]
	n: 1
	count: 31
	if overflow? [n: n << count][return false]
	true
]

division-tests: func [
	return: [logic!]
	/local a [integer!] b [integer!] q [integer!]
][
	a: -2147483648
	b: -1
	q: 0
	if not overflow? [q: a / b][return false]
	if not overflow? [q: a // b][return false]
	if not overflow? [q: a % b][return false]
	a: 100
	b: 5
	if overflow? [q: a / b][return false]
	a: -100
	if overflow? [q: a / b][return false]
	true
]

wide-tests: func [
	return: [integer!]
	/local s [int64!] u [uint64!]
][
	s: as int64! 1
	u: as uint64! 1
	if overflow? [s: s + (as int64! 2)][return 20]
	if not overflow? [s: (as int64! 7FFFFFFFFFFFFFFFh) + (as int64! 1)][
		return 21
	]
	if not overflow? [s: (as int64! 8000000000000000h) - (as int64! 1)][
		return 22
	]
	if overflow? [s: (as int64! 0000000100000000h) * (as int64! 2)][
		return 23
	]
	if not overflow? [s: (as int64! 7FFFFFFFFFFFFFFFh) * (as int64! 2)][
		return 24
	]
	s: as int64! 1
	if overflow? [s: s << 62][return 25]
	s: as int64! 1
	if not overflow? [s: s << 63][return 26]
	if overflow? [u: u + (as uint64! 2)][return 27]
	if not overflow? [u: (as uint64! FFFFFFFFFFFFFFFFh) + (as uint64! 1)][
		return 28
	]
	if not overflow? [u: (as uint64! 0) - (as uint64! 1)][return 29]
	if overflow? [u: (as uint64! 0000000100000000h) * (as uint64! 2)][
		return 30
	]
	if not overflow? [u: (as uint64! FFFFFFFFFFFFFFFFh) * (as uint64! 2)][
		return 31
	]
	u: as uint64! 1
	if overflow? [u: u << 63][return 32]
	u: as uint64! 2
	if not overflow? [u: u << 63][return 33]
	0
]

control-tests: func [
	return: [logic!]
	/local n [integer!] q [integer!] inner? [logic!] step [subroutine!]
][
	n: 0
	q: 0
	inner?: false
	step: [q: 2147483647 + 1]
	if not overflow? [
		n: n + 1
		q: 2147483647 + 1
		n: n + 100
	][return false]
	if n <> 1 [return false]
	n: 0
	if not overflow? [
		q: 65536 * 65536
		n: n + 1
	][return false]
	if n <> 0 [return false]
	inner?: overflow? [q: 2147483647 + 1]
	if not inner? [return false]
	if overflow? [
		inner?: overflow? [q: 2147483647 + 1]
		false
	][return false]
	if not overflow? [
		inner?: overflow? [q: 1 + 1]
		n: 2147483647 + 1
	][return false]
	if overflow? [q: overflows-internally][return false]
	if overflow? [step][return false]
	if overflow? [q: 1 + 1][return false]
	if not (false or overflow? [q: 2147483647 + 1])[return false]
	if true and overflow? [q: 1 + 1][return false]
	true
]

main: func [return: [integer!] /local status [integer!]][
	if not basic-tests [return 1]
	if not signed-tests [return 2]
	if not narrow-tests [return 3]
	if not shift-tests [return 4]
	if not division-tests [return 5]
	status: wide-tests
	if status <> 0 [return status]
	if not control-tests [return 7]
	73
]

process-exit main
