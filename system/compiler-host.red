Red [
	Title: "Host compatibility helpers for the Red/System compiler"
	File:  %compiler-host.red
]

reform: func [v][form reduce v]

join: func [
	"Concatenates values."
	value "Base value"
	rest "Value or block of values"
][
	value: either series? value [copy value] [form value]
	append value rest
]
