Red [
	Title: "Hybrid compiler native codegen routine bridge"
	File:  %codegen-bridge.red
]

#system [
	#include %../system/codegen/codegen-bridge.reds
]

codegen-module: routine [
	ir          [binary!]
	config      [binary!]
	artifact    [binary!]
	diagnostics [binary!]
	return:     [integer!]
][
	wire-codegen-bridge/run ir config artifact diagnostics
]
