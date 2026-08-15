Red [
	Title: "Hybrid compiler native codegen routine bridge"
	File:  %codegen-bridge.red
]

#system [
	#include %../system/codegen/codegen-bridge.reds
]

codegen-module-native: routine [
	ir          [binary!]
	config      [binary!]
	artifact    [binary!]
	diagnostics [binary!]
	return:     [integer!]
][
	wire-codegen-bridge/run ir config artifact diagnostics
]

compiler-codegen-bridge: context [
	schema: compiler-wire-schema
	DEFAULT-MAX-OUTPUT-BYTES: 16777216
	DEFAULT-MAX-DIAGNOSTIC-BYTES: 65536

	read-i31: func [
		data [binary!]
		offset [integer!]
		/local high
	][
		if any [offset < 0 (offset + 4) > (length? data)][return none]
		high: to integer! pick data (offset + 4)
		if high > 127 [return none]
		(to integer! pick data (offset + 1))
			+ ((to integer! pick data (offset + 2)) * 256)
			+ ((to integer! pick data (offset + 3)) * 65536)
			+ (high * 16777216)
	]

	limits-for: func [
		config [binary!]
		/local output-limit diagnostic-limit payload-offset value
	][
		output-limit: DEFAULT-MAX-OUTPUT-BYTES
		diagnostic-limit: DEFAULT-MAX-DIAGNOSTIC-BYTES
		payload-offset: read-i31 config (
			schema/WIRE_HEADER_SIZE
			+ schema/WIRE_DIRECTORY_PAYLOAD_OFFSET_OFFSET
		)
		if integer? payload-offset [
			value: read-i31 config (
				payload-offset + schema/WIRE_RSCF_CONFIG_MAX_OUTPUT_BYTES_OFFSET
			)
			if all [
				integer? value
				value >= schema/WIRE_RSCG_MINIMUM_SIZE
				value <= DEFAULT-MAX-OUTPUT-BYTES
			][output-limit: value]
			value: read-i31 config (
				payload-offset + schema/WIRE_RSCF_CONFIG_MAX_DIAGNOSTIC_BYTES_OFFSET
			)
			if all [
				integer? value
				value >= 0
				value <= DEFAULT-MAX-DIAGNOSTIC-BYTES
				any [value = 0 value >= schema/WIRE_RSDG_MINIMUM_SIZE]
			][diagnostic-limit: value]
		]
		reduce [output-limit diagnostic-limit]
	]

	invoke: func [
		ir config artifact diagnostics [binary!]
		/local limits native-artifact native-diagnostics status
	][
		unless all [
			head? artifact
			head? diagnostics
			empty? artifact
			empty? diagnostics
			not same? ir config
			not same? ir artifact
			not same? ir diagnostics
			not same? config artifact
			not same? config diagnostics
			not same? artifact diagnostics
		][return schema/WIRE_STATUS_INVALID_ARGUMENTS]

		limits: limits-for config
		native-artifact: make binary! limits/1
		; A zero-sized binary can use the runtime's shared empty-series node.
		native-diagnostics: make binary! either limits/2 = 0 [1][limits/2]
		status: codegen-module-native ir config native-artifact native-diagnostics

		; Native code no longer holds a Red-series pointer, so ordinary Red
		; appends are safe here and preserve the public all-or-nothing contract.
		append artifact native-artifact
		append diagnostics native-diagnostics
		status
	]
]

codegen-module: func [
	ir config artifact diagnostics [binary!]
][
	compiler-codegen-bridge/invoke ir config artifact diagnostics
]
