Red/System [
	Title: "O2 Win64 imported aggregate call ABI coverage"
]

triple8!: alias struct! [
	one   [byte!]
	two   [byte!]
	three [byte!]
]

big!: alias struct! [
	one   [integer!]
	two   [integer!]
	three [float!]
]

paird!: alias struct! [
	one [float!]
	two [float!]
]

#import [
	"structlib.dll" cdecl [
		checkTriple8: "checkTriple8" [
			value [triple8! value]
			bias [integer!]
			return: [integer!]
		]
		checkBig: "checkBig" [value [big! value] return: [integer!]]
		checkPairD: "checkPairD" [value [paird! value] return: [integer!]]
	]
]

call-triple8: func [return: [integer!] /local value [triple8! value]][
	value/one: #"A"
	value/two: #"B"
	value/three: #"C"
	checkTriple8 value 7
]

call-big: func [return: [integer!] /local value [big! value]][
	value/one: 123
	value/two: 456
	value/three: 3.14
	checkBig value
]

call-paird: func [return: [integer!] /local value [paird! value]][
	value/one: 12.5
	value/two: 29.5
	checkPairD value
]

print-line call-triple8
print-line call-big
print-line call-paird
