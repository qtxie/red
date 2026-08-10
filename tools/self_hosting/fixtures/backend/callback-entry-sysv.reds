Red/System [
	Title: "Machine-IR SysV x64 callback-entry fixture"
]

paird!: alias struct! [
	one [float!]
	two [float!]
]

big!: alias struct! [
	one [integer!]
	two [integer!]
	three [float!]
]

#either OS = 'Windows [
	#import [
		"structlib-x64.dll" cdecl [
			call-paird-callback: "callPairDCallback" [
				callback [int-ptr!]
				return: [integer!]
			]
			call-big-return-callback: "callBigReturnCallback" [
				callback [int-ptr!]
				return: [integer!]
			]
			call-mixed-exhaustion-callback: "callMixedExhaustionCallback" [
				callback [int-ptr!]
				return: [integer!]
			]
		]
	]
][
	#import [
		"libstructlib-x64.so" cdecl [
			call-paird-callback: "callPairDCallback" [
				callback [int-ptr!]
				return: [integer!]
			]
			call-big-return-callback: "callBigReturnCallback" [
				callback [int-ptr!]
				return: [integer!]
			]
			call-mixed-exhaustion-callback: "callMixedExhaustionCallback" [
				callback [int-ptr!]
				return: [integer!]
			]
		]
	]
]

seen-i1: 0
seen-i6: 0
seen-i7: 0
seen-i9: 0
seen-d1?: false
seen-d8?: false
seen-d9?: false
seen-d8: 0.0

paird-callback: func [
	[cdecl]
	value [paird! value]
	bias [integer!]
	return: [integer!]
][
	((as integer! value/one) + (as integer! value/two)) + bias
]

big-return-callback: func [
	[cdecl]
	base [integer!]
	return: [big! value]
	/local value [big! value]
][
	value/one: 118 + base
	value/two: 451 + base
	value/three: 3.14
	value
]

mixed-exhaustion-callback: func [
	[cdecl]
	i1 [integer!] d1 [float!]
	i2 [integer!] d2 [float!]
	i3 [integer!] d3 [float!]
	i4 [integer!] d4 [float!]
	i5 [integer!] d5 [float!]
	i6 [integer!] d6 [float!]
	i7 [integer!] d7 [float!]
	i8 [integer!] d8 [float!]
	i9 [integer!] d9 [float!]
	return: [integer!]
][
	seen-i1: i1
	seen-i6: i6
	seen-i7: i7
	seen-i9: i9
	seen-d1?: d1 = 1.5
	seen-d8?: d8 = 8.5
	seen-d9?: d9 = 9.5
	seen-d8: d8
	1
]

print-line call-paird-callback as int-ptr! :paird-callback
print-line call-big-return-callback as int-ptr! :big-return-callback
print-line call-mixed-exhaustion-callback as int-ptr! :mixed-exhaustion-callback
print-line seen-i1
print-line seen-i6
print-line seen-i7
print-line seen-i9
print-line seen-d1?
print-line seen-d8?
print-line seen-d9?
print-line seen-d8

unless all [
	seen-i1 = 1
	seen-i6 = 6
	seen-i7 = 7
	seen-i9 = 9
	seen-d1?
	seen-d8?
	seen-d9?
	seen-d8 = 8.5
][
	quit 1
]
