Red [
	Title: "Compiled local block evaluation probe"
]

consume: func [value [word! none!]][value]

conditions: context [
	pairs: transcode {
		overflow? not-overflow?
		not-overflow? overflow?
		= <>
		<> =
		even? odd?
		odd? even?
		< >=
		>= <
		<= >
		> <=
	}
	opposite?: func [condition [word!]][select/skip pairs condition 2]
]

round-trip: func [
	value [word! none!]
	/local delayed
][
	delayed: [consume value]
	do delayed
]

repeat n 100000 [
	unless 'greater = round-trip 'greater [
		print ["FAIL: compiled local block lost its value at iteration" n]
		quit/return 1
	]
]

unless all [
	'> = conditions/opposite? '<=
	'<= = conditions/opposite? '>
][
	print ["FAIL: compiled SELECT/SKIP lookup returned" mold reduce [
		conditions/opposite? '<=
		conditions/opposite? '>
	]]
	quit/return 1
]

print "PASS: compiled local block preserved its value"
