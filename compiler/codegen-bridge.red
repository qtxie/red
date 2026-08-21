Red [
	Title: "Hybrid compiler native codegen routine"
	File:  %codegen-bridge.red
]

#system [
	#include %../system/codegen/codegen-bridge.reds
]

emit-rsir-instruction: routine [
	output [binary!]
	op [integer!]
	a [integer!]
	b [integer!]
	c [integer!]
	return: [integer!]
	/local series [series!]
		tail [byte-ptr!]
		instruction [rsir-instruction!]
][
	series: GET_BUFFER(output)
	tail: as byte-ptr! series/tail
	if (tail + 16) > ((as byte-ptr! series + 1) + series/size) [return 0]
	instruction: as rsir-instruction! tail
	instruction/op: op
	instruction/a: a
	instruction/b: b
	instruction/c: c
	series/tail: as cell! tail + 16
	1
]

codegen-module: routine [
	ir        [binary!]
	artifact  [binary!]
	opt-level [integer!]
	return:   [integer!]
][
	codegen-bridge/run ir artifact opt-level
]
