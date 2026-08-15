Red [
	Title: "Hybrid compiler native codegen routine"
	File:  %codegen-bridge.red
]

#system [
	#include %../system/codegen/codegen-bridge.reds
]

codegen-module: routine [
	ir        [binary!]
	artifact  [binary!]
	opt-level [integer!]
	return:   [integer!]
][
	codegen-bridge/run ir artifact opt-level
]
