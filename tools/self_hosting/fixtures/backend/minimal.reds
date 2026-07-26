Red/System [
	Title: "Self-hosted IA-32 compiler fixture"
]

answer: func [return: [integer!]][
	42
]

box: declare struct! [value [integer!]]

box-value-address: func [return: [pointer! [integer!]]][
	:box/value
]

answer
