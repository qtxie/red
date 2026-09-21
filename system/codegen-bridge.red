Red [
	Title: "Hybrid compiler native codegen routine"
	File:  %system/codegen-bridge.red
]

#system [
	#include %codegen/codegen-bridge.reds
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
	ir           [binary!]
	artifact     [binary!]
	architecture [integer!]
	abi          [integer!]
	opt-level    [integer!]
	return:      [integer!]
][
	codegen-bridge/run ir artifact architecture abi opt-level
]

codegen-required: routine [return: [integer!]][
	either codegen-diag/status = codegen-diag/OUTPUT_FULL [codegen-diag/expected][0]
]

codegen-report: routine [][
	codegen-diag/report
]
