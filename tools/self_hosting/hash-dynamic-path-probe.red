Red [
	Title: "Compiled dynamic hash path probe"
]

probe: context [
	symbols: make hash! 16
	name: '_native_
	enabled?: no

	lookup: func [/local spec][
		spec: either enabled? [
			symbols/:name
		][
			name: to word! rejoin [name 123]
			enabled?: yes
			repend symbols [name spec: reduce ['native none make block! 5]]
			spec
		]
		spec
	]
]

first-result: probe/lookup
second-result: probe/lookup

either all [
	block? first-result
	block? second-result
	equal? first-result second-result
][
	print "PASS: dynamic hash lookup preserved the appended value"
][
	print ["FAIL:" mold reduce [first-result second-result probe/symbols]]
	quit/return 1
]
